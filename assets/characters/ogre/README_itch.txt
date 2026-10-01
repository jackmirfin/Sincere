Ogre Pack

Contents:
- frames/ogre: cleaned high-resolution PNG frames, 1024x1024 each
- sheets/ogre_sheet_clean.png: high-resolution spritesheet, 6144x1024
- pixelart/ogre_common_scale_cropped: cropped pixelart PNG frames using one shared character scale
- pixelart/sheets/ogre_pixelart_common_scale_sheet.png: shared-scale pixelart spritesheet with baseline alignment
- pixelart/ogre_common_scale_cropped/pixelart_common_frames.json: frame metadata
- pixelart/sheets/ogre_pixelart_common_scale_sheet.json: spritesheet metadata
- LICENSE.txt: commercial usage license in English and Spanish

Technical notes:
- Alpha is binary only: 0 or 255
- Background pixels are fully transparent RGBA(0,0,0,0)
- Pixelart frames are cropped to the real visible sprite bounds
- Shared-scale pixelart uses ogre_idle visible height = 128 px as reference
- Shared-scale death frame is wider and taller than a max-128 normalized export, so it keeps visual scale with standing poses
- Pixelart color is quantized and exported without semitransparency

Suggested itch.io tags: 2D, sprites, enemy, fantasy, dungeon, pixel-art, PNG

