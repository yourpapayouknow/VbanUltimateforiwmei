#!/usr/bin/env python3
"""
生成符合 Apple macOS HIG 官方规范的标准圆角矩形 (Squircle) AppIcon 与 .icns 文件
- 主体尺寸: 824 x 824 px (位于 1024 x 1024 画布中轴)
- 圆角半径: ~185 px (连续平滑圆角曲率)
- 阴影体系: macOS 官方双层柔和落影 (Ambient + Key shadow)
- 边框质感: 0.8pt 细微内侧半透明描边
- 官方工具: iconutil -c icns 生成 10 档完整分辨率规格
"""

import os
import shutil
import subprocess
from PIL import Image, ImageDraw, ImageFilter

def create_squircle_mask(size, radius, supersample=4):
    w, h = size
    sw, sh = w * supersample, h * supersample
    sr = radius * supersample
    
    mask = Image.new("L", (sw, sh), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle([0, 0, sw - 1, sh - 1], radius=sr, fill=255)
    
    return mask.resize((w, h), Image.Resampling.LANCZOS)

def generate_macos_icon(src_path, dst_png_path, dst_icns_path):
    print(f"Loading source icon: {src_path}")
    src = Image.open(src_path).convert("RGBA")
    
    # 官方标准参数
    canvas_size = 1024
    body_size = 824
    corner_radius = 185
    offset_x = (canvas_size - body_size) // 2  # 100
    offset_y = 92  # 稍微上移 8px 给下方投影留出空间
    
    # 1. 缩放原图并裁切为标准圆角矩形
    resized_src = src.resize((body_size, body_size), Image.Resampling.LANCZOS)
    mask = create_squircle_mask((body_size, body_size), corner_radius, supersample=4)
    
    body = Image.new("RGBA", (body_size, body_size), (0, 0, 0, 0))
    body.paste(resized_src, (0, 0), mask)
    
    # 2. 增加 1px 细微内描边增加质感
    stroke_mask = Image.new("L", (body_size * 2, body_size * 2), 0)
    stroke_draw = ImageDraw.Draw(stroke_mask)
    stroke_draw.rounded_rectangle([0, 0, body_size * 2 - 1, body_size * 2 - 1], 
                                  radius=corner_radius * 2, outline=255, width=2)
    fine_stroke = stroke_mask.resize((body_size, body_size), Image.Resampling.LANCZOS)
    
    border_layer = Image.new("RGBA", (body_size, body_size), (255, 255, 255, 30))
    body.paste(border_layer, (0, 0), fine_stroke)
    
    # 3. 构造 macOS 官方双层柔和下落投影
    canvas = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    
    # 环境阴影 (Ambient Shadow)
    ambient_shadow = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    ambient_mask = Image.new("L", (canvas_size, canvas_size), 0)
    ambient_mask.paste(mask, (offset_x, offset_y + 4))
    ambient_mask = ambient_mask.filter(ImageFilter.GaussianBlur(radius=12))
    ambient_shadow.paste(Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, int(255 * 0.18))), (0, 0), ambient_mask)
    
    # 主光源落影 (Key Drop Shadow)
    key_shadow = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    key_mask = Image.new("L", (canvas_size, canvas_size), 0)
    key_mask.paste(mask, (offset_x, offset_y + 16))
    key_mask = key_mask.filter(ImageFilter.GaussianBlur(radius=24))
    key_shadow.paste(Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, int(255 * 0.28))), (0, 0), key_mask)
    
    # 4. 逐层合成到主画布
    canvas = Image.alpha_composite(canvas, ambient_shadow)
    canvas = Image.alpha_composite(canvas, key_shadow)
    canvas.paste(body, (offset_x, offset_y), body)
    
    # 5. 保存带官方圆角和投影的标准 1024x1024 PNG
    canvas.save(dst_png_path, "PNG")
    print(f"Saved standard macOS HIG AppIcon: {dst_png_path}")
    
    # 6. 生成标准 AppIcon.iconset 目录
    iconset_dir = "/tmp/VBANAppIcon.iconset"
    if os.path.exists(iconset_dir):
        shutil.rmtree(iconset_dir)
    os.makedirs(iconset_dir, exist_ok=True)
    
    scales = [
        (16, 1), (16, 2),
        (32, 1), (32, 2),
        (128, 1), (128, 2),
        (256, 1), (256, 2),
        (512, 1), (512, 2)
    ]
    
    for base_size, scale in scales:
        pixel_size = base_size * scale
        if scale == 1:
            filename = f"icon_{base_size}x{base_size}.png"
        else:
            filename = f"icon_{base_size}x{base_size}@{scale}x.png"
        
        resized_icon = canvas.resize((pixel_size, pixel_size), Image.Resampling.LANCZOS)
        resized_icon.save(os.path.join(iconset_dir, filename), "PNG")
    
    # 7. 调用官方 iconutil 编译生成 .icns
    cmd = ["iconutil", "-c", "icns", iconset_dir, "-o", dst_icns_path]
    print("Running:", " ".join(cmd))
    subprocess.check_call(cmd)
    print(f"Successfully generated macOS .icns: {dst_icns_path}")
    
    # 清理临时 iconset
    shutil.rmtree(iconset_dir)

if __name__ == "__main__":
    project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    src_icon = os.path.join(project_root, "Resources", "AppIcon.png")
    dst_icon_png = os.path.join(project_root, "Resources", "AppIcon.png")
    dst_icon_icns = os.path.join(project_root, "Resources", "AppIcon.icns")
    
    # 保留一份原始正方形备份
    backup_raw = os.path.join(project_root, "Resources", "AppIcon_Square_Original.png")
    if not os.path.exists(backup_raw):
        shutil.copyfile(src_icon, backup_raw)
        print(f"Backed up original square icon to: {backup_raw}")
        input_src = backup_raw
    else:
        input_src = backup_raw
        
    generate_macos_icon(input_src, dst_icon_png, dst_icon_icns)
