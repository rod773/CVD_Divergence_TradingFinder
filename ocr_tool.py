"""
OCR Tool - Extract text from screenshots or image files.
Usage:
  python ocr_tool.py                    # interactive screenshot region
  python ocr_tool.py image.png          # OCR a file
  python ocr_tool.py --clipboard        # OCR clipboard image
"""

import sys
import os
import tempfile
from PIL import Image

try:
    import pytesseract
except ImportError:
    print("Missing pytesseract. Install: pip install pytesseract")
    sys.exit(1)

try:
    import pyautogui
except ImportError:
    pyautogui = None

try:
    from PIL import ImageGrab
except ImportError:
    ImageGrab = None


def ocr_image(img, lang="eng"):
    try:
        text = pytesseract.image_to_string(img, lang=lang)
        return text.strip()
    except Exception as e:
        return f"OCR error: {e}\nMake sure Tesseract is installed: https://github.com/UB-Mannheim/tesseract/wiki"


if __name__ == "__main__":
    lang = sys.argv[2] if len(sys.argv) > 2 and not sys.argv[2].startswith("--") else "eng"

    if len(sys.argv) > 1 and sys.argv[1] != "--clipboard":
        path = sys.argv[1]
        if os.path.isfile(path):
            img = Image.open(path)
            print(ocr_image(img, lang))
            sys.exit(0)
        else:
            print(f"File not found: {path}")
            sys.exit(1)

    if "--clipboard" in sys.argv:
        try:
            img = ImageGrab.grabclipboard()
            if img is None:
                print("No image on clipboard.")
                sys.exit(1)
            print(ocr_image(img, lang))
        except Exception as e:
            print(f"Clipboard error: {e}")
        sys.exit(0)

    # Interactive screenshot mode
    try:
        if pyautogui is None:
            print("Install pyautogui: pip install pyautogui")
            sys.exit(1)

        print("Move mouse to top-left corner of region and press Enter...")
        input()
        x1, y1 = pyautogui.position()

        print("Move mouse to bottom-right corner and press Enter...")
        input()
        x2, y2 = pyautogui.position()

        left = min(x1, x2)
        top = min(y1, y2)
        width = abs(x2 - x1)
        height = abs(y2 - y1)

        if width < 5 or height < 5:
            print("Region too small.")
            sys.exit(1)

        screenshot = pyautogui.screenshot(region=(left, top, width, height))
        print(ocr_image(screenshot, lang))

    except KeyboardInterrupt:
        print("\nCancelled.")
