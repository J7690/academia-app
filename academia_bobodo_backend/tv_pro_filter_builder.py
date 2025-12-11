from typing import Any, Dict, List, Tuple


def _as_float(value: Any, default: float = 0.0) -> float:
    try:
        if value is None:
            return default
        return float(value)
    except (TypeError, ValueError):
        return default


def _time_window(ov: Dict[str, Any]) -> Tuple[float, float]:
    start = ov.get("start_at_seconds")
    if start is None:
        start = ov.get("start_at")
    end = ov.get("end_at_seconds")
    if end is None:
        end = ov.get("end_at")
    s = _as_float(start, 0.0)
    e = _as_float(end, s + 5.0)
    if e <= s:
        e = s + 5.0
    return s, e


def _enable_expr(s: float, e: float) -> str:
    return f"between(t,{s:.3f},{e:.3f})"


def _resolve_position(ov: Dict[str, Any]) -> Tuple[str, str]:
    pos = ov.get("position") or {}
    if not isinstance(pos, dict):
        pos = {}
    align = ov.get("align") or pos.get("align") or pos.get("position")
    a = str(align or "").strip().lower()
    x = pos.get("x", ov.get("x"))
    y = pos.get("y", ov.get("y"))
    if isinstance(x, (int, float)) and isinstance(y, (int, float)):
        return str(int(x)), str(int(y))
    if a == "top_left":
        return "40", "40"
    if a == "top_center":
        return "(w-tw)/2", "40"
    if a == "top_right":
        return "w-tw-40", "40"
    if a == "bottom_left":
        return "40", "h-th-80"
    if a == "bottom_center":
        return "(w-tw)/2", "h-th-80"
    if a == "bottom_right":
        return "w-tw-40", "h-th-80"
    if a == "center":
        return "(w-tw)/2", "(h-th)/2"
    return "(w-tw)/2", "h-th-80"


def _normalize_type(raw: Any) -> str:
    t = str(raw or "").strip().lower()
    if not t:
        return "text"
    return t


def _extract_source_url(ov: Dict[str, Any]) -> str:
    for key in ("source_url", "url", "src"):
        raw = ov.get(key)
        if raw is None:
            continue
        s = str(raw).strip()
        if s:
            return s
    return ""


def _extract_keyframes(ov: Dict[str, Any]) -> List[Dict[str, Any]]:
    raw = ov.get("keyframes")
    if not isinstance(raw, list):
        return []
    frames: List[Dict[str, Any]] = []
    for kf in raw:
        if isinstance(kf, dict):
            frames.append(kf)
    return frames


def _build_keyframe_1d_expr(ov: Dict[str, Any], field: str, s: float, e: float) -> str:
    frames = _extract_keyframes(ov)
    points: List[Tuple[float, float]] = []
    for kf in frames:
        if field not in kf:
            continue
        try:
            v = float(kf[field])
        except (TypeError, ValueError):
            continue
        t_local = _as_float(kf.get("t"), 0.0)
        t_abs = s + t_local
        points.append((t_abs, v))

    if not points:
        return ""

    points.sort(key=lambda p: p[0])

    if len(points) == 1:
        return f"{points[0][1]:.6f}"

    expr_parts: List[str] = []
    t0, v0 = points[0]
    expr = f"if(lte(t,{t0:.3f}),{v0:.6f},"
    expr_parts.append(expr)

    for i in range(len(points) - 1):
        ti, vi = points[i]
        tj, vj = points[i + 1]
        if tj <= ti:
            continue
        num = f"{vi:.6f}+({vj - vi:.6f})*(t-{ti:.3f})/({tj - ti:.3f})"
        expr_parts.append(f"if(lt(t,{tj:.3f}),{num},")

    vn = points[-1][1]
    expr_parts.append(f"{vn:.6f}")
    expr_parts.append(")" * (len(points)))

    return "".join(expr_parts)


def _get_animation(ov: Dict[str, Any]) -> Dict[str, Any]:
    anim = ov.get("animation")
    if isinstance(anim, dict):
        return anim
    return {}


def _get_transform(ov: Dict[str, Any]) -> Dict[str, Any]:
    tr = ov.get("transform")
    if isinstance(tr, dict):
        return tr
    return {}


def _build_motion_expr(ov: Dict[str, Any], s: float, e: float, base_x: str, base_y: str) -> Tuple[str, str]:
    kf_x_expr = _build_keyframe_1d_expr(ov, "x", s, e)
    kf_y_expr = _build_keyframe_1d_expr(ov, "y", s, e)
    if kf_x_expr or kf_y_expr:
        x_expr = kf_x_expr or base_x
        y_expr = kf_y_expr or base_y
        return x_expr, y_expr

    anim = _get_animation(ov)
    mode = str(anim.get("mode") or "").strip().lower()
    if not mode:
        return base_x, base_y

    d = e - s
    if d <= 0.0:
        d = 0.001

    if mode == "slide_from_left":
        start_x = "-W"
        x_expr = f"({start_x}) + (({base_x})-({start_x}))*((t-{s:.3f})/{d:.3f})"
        return x_expr, base_y

    if mode == "slide_from_right":
        start_x = "w+W"
        x_expr = f"({start_x}) + (({base_x})-({start_x}))*((t-{s:.3f})/{d:.3f})"
        return x_expr, base_y

    if mode == "slide_from_top":
        start_y = "-H"
        y_expr = f"({start_y}) + (({base_y})-({start_y}))*((t-{s:.3f})/{d:.3f})"
        return base_x, y_expr

    if mode == "slide_from_bottom":
        start_y = "h+H"
        y_expr = f"({start_y}) + (({base_y})-({start_y}))*((t-{s:.3f})/{d:.3f})"
        return base_x, y_expr

    if mode == "slide_out_x":
        end_x = "w+W"
        x_expr = f"({base_x}) + (({end_x})-({base_x}))*((t-{s:.3f})/{d:.3f})"
        return x_expr, base_y

    if mode == "slide_out_y":
        end_y = "h+H"
        y_expr = f"({base_y}) + (({end_y})-({base_y}))*((t-{s:.3f})/{d:.3f})"
        return base_x, y_expr

    return base_x, base_y


def _build_scale_rotate_alpha(ov: Dict[str, Any], s: float, e: float) -> Tuple[str, str, str, str]:
    transform = _get_transform(ov)
    ov_type = _normalize_type(ov.get("type") or ov.get("overlay_type"))
    d = e - s
    if d <= 0.0:
        d = 0.001

    scale_w = ""
    scale_h = ""
    rotate_expr = ""
    alpha_expr = ""

    kf_scale = _build_keyframe_1d_expr(ov, "scale", s, e)
    kf_rotate = _build_keyframe_1d_expr(ov, "rotate", s, e)
    kf_opacity = _build_keyframe_1d_expr(ov, "opacity", s, e)

    if kf_scale:
        scale_w = f"iw*({kf_scale})"
        scale_h = f"ih*({kf_scale})"
    else:
        scale_target = transform.get("scale")
        if scale_target is None and ov_type == "pip":
            pip_opts = ov.get("pip_options")
            if isinstance(pip_opts, dict):
                scale_target = pip_opts.get("scale")
        if isinstance(scale_target, (int, float)):
            st = float(scale_target)
            if st != 1.0:
                scale_w = f"iw*(1+({st}-1)*((t-{s:.3f})/{d:.3f}))"
                scale_h = f"ih*(1+({st}-1)*((t-{s:.3f})/{d:.3f}))"

    if kf_rotate:
        rotate_expr = f"PI/180*({kf_rotate})"
    else:
        rotate_target = transform.get("rotate")
        if isinstance(rotate_target, (int, float)):
            rt = float(rotate_target)
            if rt != 0.0:
                rotate_expr = f"PI/180*({rt}*((t-{s:.3f})/{d:.3f}))"

    if kf_opacity:
        alpha_expr = f"if(between(t,{s:.3f},{e:.3f}),{kf_opacity},0)"
    else:
        opacity_target = transform.get("opacity")
        if isinstance(opacity_target, (int, float)):
            op = float(opacity_target)
            if op <= 0.0:
                alpha_expr = f"if(between(t,{s:.3f},{e:.3f}),0,0)"
            elif op >= 1.0:
                alpha_expr = f"if(between(t,{s:.3f},{e:.3f}),1,0)"
            else:
                alpha_expr = f"if(between(t,{s:.3f},{e:.3f}),{op}*((t-{s:.3f})/{d:.3f}),0)"

    return scale_w, scale_h, rotate_expr, alpha_expr


def _build_text_filter(ov: Dict[str, Any], s: float, e: float) -> str:
    text = ov.get("text") or ov.get("title")
    if text is None:
        return ""
    txt = str(text).strip()
    if not txt:
        return ""

    enable = _enable_expr(s, e)

    fontcolor = str(ov.get("fontcolor") or ov.get("font_color") or "white").strip() or "white"
    fontsize = int(_as_float(ov.get("fontsize") or ov.get("font_size"), 32))
    boxcolor = str(ov.get("boxcolor") or ov.get("box_color") or "black@0.5").strip() or "black@0.5"
    boxborderw = int(_as_float(ov.get("boxborderw") or ov.get("box_border_width"), 10))

    x_expr, y_expr = _resolve_position(ov)

    ov_type = _normalize_type(ov.get("type") or ov.get("overlay_type"))
    if ov_type == "ticker":
        base_t = f"{s:.3f}"
        speed = _as_float(ov.get("speed") or ov.get("speed_px_per_s") or ov.get("pixels_per_second"), 100.0)
        if speed <= 0:
            speed = 100.0
        x_expr = f"w-mod((t-{base_t})*{speed},w+tw)"
        y_expr = "h-th-40"

    x_expr, y_expr = _build_motion_expr(ov, s, e, x_expr, y_expr)

    escaped = txt.replace("'", "\\'")
    return (
        "drawtext=text='{text}':fontcolor={fontcolor}:fontsize={fontsize}:"
        "x={x}:y={y}:box=1:boxcolor={boxcolor}:boxborderw={boxborderw}:enable='{enable}'"
    ).format(
        text=escaped,
        fontcolor=fontcolor,
        fontsize=fontsize,
        x=x_expr,
        y=y_expr,
        boxcolor=boxcolor,
        boxborderw=boxborderw,
        enable=enable,
    )


def build_tv_pro_filtergraph(timeline: Dict[str, Any]) -> Dict[str, Any]:
    overlays_raw = timeline.get("overlays") or []
    if not isinstance(overlays_raw, list):
        overlays_raw = []

    def _sort_key(ov: Any) -> Tuple[float, int]:
        if not isinstance(ov, dict):
            return 0.0, 0
        s, _ = _time_window(ov)
        so = ov.get("sort_order")
        try:
            so_i = int(so) if so is not None else 0
        except (TypeError, ValueError):
            so_i = 0
        return s, so_i

    overlays: List[Dict[str, Any]] = [ov for ov in overlays_raw if isinstance(ov, dict)]
    overlays.sort(key=_sort_key)

    overlay_source_urls: List[str] = []

    chains: List[str] = []
    current_label = "base0"
    chains.append("[0:v]format=yuv420p[base0]")
    next_index = 0

    def _next_label() -> str:
        nonlocal next_index
        next_index += 1
        return f"v{next_index}"

    ops_count = 0

    for ov in overlays:
        ov_type = _normalize_type(ov.get("type") or ov.get("overlay_type"))
        s, e = _time_window(ov)

        if ov_type in ("text", "banner", "lower_third", "ticker"):
            draw = _build_text_filter(ov, s, e)
            if not draw:
                continue
            next_label = _next_label()
            chains.append(f"[{current_label}]{draw}[{next_label}]")
            current_label = next_label
            ops_count += 1
            if ops_count >= 24:
                break
            continue

        if ov_type in ("background", "image", "video", "pip"):
            bg_mode = ""
            if ov_type == "background":
                raw_bg_mode = ov.get("background_mode")
                if isinstance(raw_bg_mode, str):
                    bg_mode = raw_bg_mode.strip().lower()

            if ov_type == "background" and bg_mode in ("blur", "colorize"):
                tmp_label = _next_label()
                if bg_mode == "blur":
                    chains.append(
                        f"[{current_label}]boxblur=luma_radius=20:luma_power=1[{tmp_label}]"
                    )
                else:
                    curves = ov.get("colorize_curves") or {}
                    if not isinstance(curves, dict):
                        curves = {}
                    r = str(curves.get("r") or "0")
                    g = str(curves.get("g") or "0")
                    b = str(curves.get("b") or "0")
                    chains.append(
                        f"[{current_label}]curves=r='{r}':g='{g}':b='{b}'[{tmp_label}]"
                    )
                current_label = tmp_label
                ops_count += 1
                if ops_count >= 24:
                    break
                continue

            if ov_type == "background" and bg_mode == "replace":
                src = _extract_source_url(ov)
                if not src:
                    continue
                if src not in overlay_source_urls:
                    overlay_source_urls.append(src)
                input_idx = overlay_source_urls.index(src) + 1

                scale_w, scale_h, rotate_expr, alpha_expr = _build_scale_rotate_alpha(ov, s, e)

                source_label = f"{input_idx}:v"
                ov_label = source_label

                if scale_w and scale_h:
                    tmp_label = _next_label()
                    chains.append(f"[{ov_label}]scale={scale_w}:{scale_h}[{tmp_label}]")
                    ov_label = tmp_label

                if rotate_expr:
                    tmp_label = _next_label()
                    chains.append(f"[{ov_label}]rotate={rotate_expr}[{tmp_label}]")
                    ov_label = tmp_label

                if alpha_expr:
                    tmp_label = _next_label()
                    chains.append(
                        f"[{ov_label}]format=rgba,colorchannelmixer=aa='{alpha_expr}'[{tmp_label}]"
                    )
                    ov_label = tmp_label

                next_label = _next_label()
                chains.append(f"[{ov_label}]format=yuv420p[{next_label}]")
                current_label = next_label
                ops_count += 1
                if ops_count >= 24:
                    break
                continue

            src = _extract_source_url(ov)
            if not src:
                continue
            if src not in overlay_source_urls:
                overlay_source_urls.append(src)
            input_idx = overlay_source_urls.index(src) + 1  # input 0 = base vidéo

            enable = _enable_expr(s, e)

            if ov_type == "background":
                base_x, base_y = "0", "0"
            else:
                base_x, base_y = _resolve_position(ov)

            x_expr, y_expr = _build_motion_expr(ov, s, e, base_x, base_y)

            scale_w, scale_h, rotate_expr, alpha_expr = _build_scale_rotate_alpha(ov, s, e)

            source_label = f"{input_idx}:v"
            ov_label = source_label

            if scale_w and scale_h:
                tmp_label = _next_label()
                chains.append(f"[{ov_label}]scale={scale_w}:{scale_h}[{tmp_label}]")
                ov_label = tmp_label

            if rotate_expr:
                tmp_label = _next_label()
                chains.append(f"[{ov_label}]rotate={rotate_expr}[{tmp_label}]")
                ov_label = tmp_label

            if alpha_expr:
                tmp_label = _next_label()
                chains.append(
                    f"[{ov_label}]format=rgba,colorchannelmixer=aa='{alpha_expr}'[{tmp_label}]"
                )
                ov_label = tmp_label

            if ov_type == "pip":
                pip_opts = ov.get("pip_options")
                if isinstance(pip_opts, dict):
                    border_width = pip_opts.get("border_width")
                    border_color = pip_opts.get("border_color") or "white"
                    if isinstance(border_width, (int, float)) and border_width > 0:
                        bw = int(border_width)
                        tmp_label = _next_label()
                        chains.append(
                            f"[{ov_label}]pad=iw+2*{bw}:ih+2*{bw}:{bw}:{bw}:color={border_color}[{tmp_label}]"
                        )
                        ov_label = tmp_label

                    if pip_opts.get("rounded_corners"):
                        radius = pip_opts.get("corner_radius")
                        try:
                            r_int = int(radius) if radius is not None else 16
                        except (TypeError, ValueError):
                            r_int = 16
                        fg_label = _next_label()
                        alpha_src = _next_label()
                        alpha_blur = _next_label()
                        merged = _next_label()
                        chains.append(f"[{ov_label}]format=rgba,split[{fg_label}][{alpha_src}]")
                        chains.append(
                            f"[{alpha_src}]alphaextract,boxblur=luma_radius={r_int}:luma_power=1[{alpha_blur}]"
                        )
                        chains.append(f"[{fg_label}][{alpha_blur}]alphamerge[{merged}]")
                        ov_label = merged

                    if pip_opts.get("shadow"):
                        try:
                            shadow_dx = int(pip_opts.get("shadow_dx") or 8)
                        except (TypeError, ValueError):
                            shadow_dx = 8
                        try:
                            shadow_dy = int(pip_opts.get("shadow_dy") or 8)
                        except (TypeError, ValueError):
                            shadow_dy = 8

                        fg_label = _next_label()
                        shadow_label = _next_label()
                        chains.append(f"[{ov_label}]split[{fg_label}][{shadow_label}]")
                        shadow_blur = _next_label()
                        chains.append(
                            f"[{shadow_label}]format=rgba,boxblur=luma_radius=10:luma_power=1,colorchannelmixer=aa=0.5[{shadow_blur}]"
                        )

                        shadow_x = f"({x_expr})+{shadow_dx}"
                        shadow_y = f"({y_expr})+{shadow_dy}"
                        base_with_shadow = _next_label()
                        chains.append(
                            f"[{current_label}][{shadow_blur}]overlay={shadow_x}:{shadow_y}:enable='{enable}'[{base_with_shadow}]"
                        )
                        current_label = base_with_shadow
                        ov_label = fg_label

            next_label = _next_label()
            chains.append(
                f"[{current_label}][{ov_label}]overlay={x_expr}:{y_expr}:enable='{enable}'[{next_label}]"
            )
            current_label = next_label
            ops_count += 1
            if ops_count >= 24:
                break

    if ops_count == 0:
        return {
            "overlay_source_urls": [],
            "filter_complex": "[0:v]format=yuv420p[vout]",
        }

    chains.append(f"[{current_label}]copy[vout]")
    filter_complex = ";".join(chains)

    return {
        "overlay_source_urls": overlay_source_urls,
        "filter_complex": filter_complex,
    }
