# rs-sphere
This tiny library contains two Polymer elements: `<rs-sphere>` and `<rs-sphere-viewer>`.
Both display 3d panoramas, the first one is more like an
image tag while the second one is more like a viewer, including buttons and
a VR mode.

## Demo
You can see a demo of the sphere viewer [here](https://lemaik.github.io/rs-sphere). It
uses a sphere image that was rendered with [Chunky](https://github.com/llbit/chunky).

## Usage

### rs-sphere
If you wan't to embed a panorama just like you'd embed an image, `<rs-sphere>`
is probably what you're looking for. The most basic usage is like this:

```html
<rs-sphere src="path/to/sphere.jpg"></rs-sphere>
```

That's it, one line and you get a beautiful sphere, including mouse-interaction.
But wait, there's more!

| Attribute | Type    | Default value | Description |
|-----------|---------|---------------|-------------|
| src       | string  | `null`        | URL of the sphere image
| src-right | string  | `null`        | URL of the sphere image for the right eye (for [Omni‐directional Stereo][ods] in stereo mode, the other image is used for the left eye)
| loading   | boolean | `false`       | Whether the sphere image is currently loading _(readonly)_
| fov       | number  | 75            | Field of view (~zoom)
| rotate    | boolean | `false`       | Toggle automatic rotation of the sphere
| stereo    | boolean | `false`       | Toggle stereo mode (for VR, i.e. Cardboard)
| gyroscope | boolean | `false`       | Toggle gyroscope to rotate the sphere according to the device's orientation
| rotate-x  | number  | 0             | Rotation around the x-axis, in radiants
| rotate-y  | number  | 0             | Rotation around the y-axis, in radiants
| rotate-z  | number  | 0             | Rotation around the z-axis, in radiants

### rs-sphere-viewer
This element wraps the basic sphere element and adds two buttons to toggle gyroscope
and stereo mode. Also, it can display the sphere in full-screen mode.

```html
<rs-sphere-viewer src="path/to/sphere.jpg"></rs-sphere-viewer>
```

That's it, one line and you get a beautiful sphere, including mouse-interaction.
But wait, there's more!

| Attribute  | Type    | Default value | Description |
|------------|---------|---------------|-------------|
| src        | string  | `null`        | URL of the sphere image
| src-right  | string  | `null`        | URL of the sphere image for the right eye (for [Omni‐directional Stereo][ods] in stereo mode, the other image is used for the left eye)
| loading    | boolean | `false`       | Whether the sphere image is currently loading _(readonly)_
| vr         | boolean | `false`       | Toggle stereo mode (for VR, i.e. Cardboard) and switches to full-screen
| gyroscope  | boolean | `false`       | Toggle gyroscope to rotate the sphere according to the device's orientation
| fullscreen | boolean | `false`       | Toggle full-screen mode

[ods]: https://developers.google.com/vr/jump/rendering-ods-content.pdf

## License
This project is licensed under the MIT license, see [the license file](LICENSE.md) for
more information.
