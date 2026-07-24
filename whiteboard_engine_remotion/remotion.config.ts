import { Config } from "@remotion/cli/config";

// Rendu vertical Reels/TikTok/Shorts. Le profil H.264 device-safe (main/4.0)
// est garanti par la finalisation ffmpeg dans render.mjs.
Config.setVideoImageFormat("jpeg");
Config.setOverwriteOutput(true);
// Chromium headless sur le VPS Kamatera (installé via `npx remotion browser ensure`).
Config.setChromiumDisableWebSecurity(false);
