import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface MergeRequest {
  segment_paths: string[]  // Storage paths to video segments
  bucket: string
  output_path: string
  transition?: 'none' | 'fade' | 'slide' | 'dissolve'
  transition_duration_ms?: number
}

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders })
  }

  try {
    const { 
      segment_paths, 
      bucket, 
      output_path, 
      transition = 'none',
      transition_duration_ms = 300 
    } = await req.json() as MergeRequest

    if (!segment_paths || segment_paths.length === 0) {
      throw new Error('No segments provided')
    }

    // Initialize Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // Download all segments to temp files
    const tempDir = await Deno.makeTempDir()
    const segmentFiles: string[] = []

    console.log(`[merge-video-segments] Downloading ${segment_paths.length} segments...`)

    for (let i = 0; i < segment_paths.length; i++) {
      const segmentPath = segment_paths[i]
      const { data, error } = await supabase.storage
        .from(bucket)
        .download(segmentPath)

      if (error || !data) {
        throw new Error(`Failed to download segment ${segmentPath}: ${error?.message}`)
      }

      const tempPath = `${tempDir}/segment_${i.toString().padStart(3, '0')}.mp4`
      const arrayBuffer = await data.arrayBuffer()
      await Deno.writeFile(tempPath, new Uint8Array(arrayBuffer))
      segmentFiles.push(tempPath)
    }

    // Create concat file for ffmpeg
    const concatFilePath = `${tempDir}/concat.txt`
    const concatContent = segmentFiles
      .map(file => `file '${file}'`)
      .join('\n')
    await Deno.writeTextFile(concatFilePath, concatContent)

    // Prepare ffmpeg command based on transition type
    const outputFile = `${tempDir}/merged.mp4`
    let ffmpegCmd: string[]

    if (transition === 'none' || segment_paths.length === 1) {
      // Simple concat without re-encoding
      ffmpegCmd = [
        'ffmpeg',
        '-f', 'concat',
        '-safe', '0',
        '-i', concatFilePath,
        '-c', 'copy',
        '-movflags', '+faststart',
        outputFile
      ]
    } else {
      // Complex filter with transitions (requires re-encoding)
      const transitionDuration = transition_duration_ms / 1000 // Convert to seconds
      const filters: string[] = []
      const inputs = segmentFiles.map((_, i) => `-i ${segmentFiles[i]}`).join(' ')
      
      // Build filter graph for transitions
      for (let i = 0; i < segmentFiles.length; i++) {
        if (i === 0) {
          filters.push(`[0:v]scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2,setsar=1[v0]`)
        } else {
          // Scale current video
          filters.push(`[${i}:v]scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2,setsar=1[v${i}]`)
          
          // Apply transition
          const prevLabel = i === 1 ? 'v0' : `out${i-1}`
          if (transition === 'fade') {
            filters.push(`[${prevLabel}][v${i}]xfade=transition=fade:duration=${transitionDuration}:offset=-${transitionDuration}[out${i}]`)
          } else if (transition === 'dissolve') {
            filters.push(`[${prevLabel}][v${i}]xfade=transition=dissolve:duration=${transitionDuration}:offset=-${transitionDuration}[out${i}]`)
          } else if (transition === 'slide') {
            filters.push(`[${prevLabel}][v${i}]xfade=transition=slideleft:duration=${transitionDuration}:offset=-${transitionDuration}[out${i}]`)
          }
        }
      }

      const finalVideoLabel = segmentFiles.length === 1 ? 'v0' : `out${segmentFiles.length - 1}`
      
      // Merge audio streams
      const audioConcat = segmentFiles.map((_, i) => `[${i}:a]`).join('') + `concat=n=${segmentFiles.length}:v=0:a=1[aout]`
      filters.push(audioConcat)

      ffmpegCmd = [
        'ffmpeg',
        ...inputs.split(' '),
        '-filter_complex', filters.join(';'),
        '-map', `[${finalVideoLabel}]`,
        '-map', '[aout]',
        '-c:v', 'libx264',
        '-preset', 'fast',
        '-crf', '23',
        '-c:a', 'aac',
        '-b:a', '128k',
        '-movflags', '+faststart',
        outputFile
      ]
    }

    console.log(`[merge-video-segments] Running ffmpeg: ${ffmpegCmd.join(' ')}`)

    // Run ffmpeg
    const process = new Deno.Command(ffmpegCmd[0], {
      args: ffmpegCmd.slice(1),
      stdout: "piped",
      stderr: "piped",
    })

    const { code, stdout, stderr } = await process.output()
    
    if (code !== 0) {
      const errorOutput = new TextDecoder().decode(stderr)
      console.error(`[merge-video-segments] FFmpeg error: ${errorOutput}`)
      throw new Error(`FFmpeg failed with code ${code}`)
    }

    // Upload merged video
    const mergedData = await Deno.readFile(outputFile)
    const { error: uploadError } = await supabase.storage
      .from(bucket)
      .upload(output_path, mergedData, {
        contentType: 'video/mp4',
        upsert: true
      })

    if (uploadError) {
      throw new Error(`Failed to upload merged video: ${uploadError.message}`)
    }

    // Cleanup temp files
    try {
      await Deno.remove(tempDir, { recursive: true })
    } catch (e) {
      console.warn('[merge-video-segments] Failed to cleanup temp dir:', e)
    }

    // Get public URL
    const { data: { publicUrl } } = supabase.storage
      .from(bucket)
      .getPublicUrl(output_path)

    return new Response(
      JSON.stringify({ 
        success: true, 
        output_path,
        public_url: publicUrl,
        segments_count: segment_paths.length,
        transition_used: transition
      }),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200 
      }
    )

  } catch (error) {
    console.error('[merge-video-segments] Error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400
      }
    )
  }
})
