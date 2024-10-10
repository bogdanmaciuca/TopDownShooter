from PIL import Image
import sys

if len(sys.argv) != 2:
    print('The script takes one argument: the name of the image.')
    exit()
filename = sys.argv[1]
image = Image.open(filename)
flipped = image.rotate(90, expand=True)

flipped.save(filename)

