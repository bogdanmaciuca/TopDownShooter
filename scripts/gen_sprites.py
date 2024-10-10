from PIL import Image

image = Image.open('res/player.png')

colors = ['red', 'blue', 'green', 'yellow']
blend_factor = 0.15

for color in colors:
    color_layer = Image.new('RGBA', image.size, color)
    new_image = Image.blend(image, color_layer, blend_factor)
    new_image.putalpha(image.split()[-1])
    #new_image.show()
    new_image.save('res/' + color + '.png')

