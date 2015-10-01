# http://blog.thematicmapping.org/2014/01/photo-spheres-with-threejs.html
# https://gist.github.com/bellbind/d2be9cc09bf6241f255d

webgl = (->
  try
    canvas = document.createElement( 'canvas' )
    return !! ( window.WebGLRenderingContext && ( canvas.getContext( 'webgl' ) || canvas.getContext( 'experimental-webgl' ) ) )
  catch
    return false
)()

endsWith = (str, suffix) -> str.indexOf(suffix, str.length - suffix.length) isnt -1

getOrientation = ->
  # W3C DeviceOrientation Event Specification (Draft)
  if (window.screen.orientation)
    return window.screen.orientation.angle;
  # Safari
  if (typeof window.orientation == "number")
    return window.orientation;
  # workaround for android firefox
  if (window.screen.mozOrientation)
    return {
    "portrait-primary": 0,
    "portrait-secondary": 180,
    "landscape-primary": 90,
    "landscape-secondary": 270,
    }[window.screen.mozOrientation]
  # otherwise
  return 0

Polymer
  is: 'rs-sphere'
  properties:
    loading:
      type: Boolean
      value: true
      reflectToAttribute: true
      readOnly: true,
      notify: true
    src:
      type: String
      observer: 'sourceChanged'
    fov:
      type: Number
      observer: 'fovChanged'
      reflectToAttribute: true
      notify: true
      value: 75
    rotate:
      type: Boolean
      observer: 'rotateChanged'
      reflectToAttribute: true
      notify: true
      value: false
    stereo:
      type: Boolean
      observer: 'stereoChanged'
      reflectToAttribute: true
      notify: true
      value: false
    gyroscope:
      type: Boolean
      observer: 'gyroscopeChanged'
      reflectToAttribute: true
      notify: true
      value: false
    rotateX:
      type: Number
      observer: 'rotateXChanged'
      reflectToAttribute: true
      notify: true
      value: 0
    rotateY:
      type: Number
      observer: 'rotateYChanged'
      reflectToAttribute: true
      notify: true
      value: 0
    rotateZ:
      type: Number
      observer: 'rotateZChanged'
      reflectToAttribute: true
      notify: true
      value: 0

  behaviors: [Polymer.IronResizableBehavior]

  listeners:
    'iron-resize': '_onIronResize'

  created: ->
    THREE.ImageUtils.crossOrigin = ''

    @scene = new THREE.Scene();

    @sphere = new THREE.Mesh(new THREE.SphereGeometry(100, 32, 32))
    @sphere.scale.x = -1

    @scene.add @sphere
    @scene.add(new THREE.AmbientLight(0x333333))

    light = new THREE.DirectionalLight(0xffffff, 1)
    light.position.set(5, 3, 5)
    @scene.add(light)

    @camera = new THREE.PerspectiveCamera(75, 0, 1, 1000)
    @camera.position.z = 1.5

    @renderer = if webgl then new THREE.WebGLRenderer() else new THREE.CanvasRenderer()
    @stereoEffect = new THREE.StereoEffect(@renderer)
    @actualRenderer = @renderer

    @_dirty = yes

  attached: ->
    @controls = new THREE.OrbitControls(@camera, @$.webgl)
    @controls.noPan = on
    @controls.noZoom = on
    @controls.noRotate = @gyroscope
    @controls.autoRotate = @rotate && !@gyroscope
    @controls.autoRotateSpeed = 0.5
    @controls.addEventListener 'change', =>
      @rotateX = @camera.rotation.x
      @rotateY = @camera.rotation.y
      @rotateZ = @camera.rotation.z
      @_dirty = yes

    render = =>
      if video?
        if video.readyState is video.HAVE_ENOUGH_DATA
          videoImageContext.drawImage(video, 0, 0)
          if (videoTexture)
            videoTexture.needsUpdate = true

      @actualRenderer.render(@scene, @camera)

    animate = =>
      if not this.gyroscope
        @controls.update()
      if @_dirty #TODO always dirty if we play a video
        @_dirty = no
        render()
      requestAnimationFrame(animate)


    webglEl = @$.webgl
    webglEl.appendChild(@renderer.domElement)
    animate()

    webglEl.addEventListener('mousewheel', ((e) => @onMouseWheel(e)), false)
    webglEl.addEventListener('DOMMouseScroll', ((e) => @onMouseWheel(e)), false)
    #webglEl.addEventListener('click', -> video?.play()) #videos only start by user interaction on mobile devices

    this.async this.notifyResize, 1

  detached: ->
    if @_gyroWrapper?
      window.removeEventListener("deviceorientation", @_gyroWrapper, false)

  sourceChanged: (src) ->
    @_setLoading true

    texture = @src
    if(endsWith(texture, '.webm') or endsWith(texture, '.mp4'))
      video = document.createElement('video')
      #video.id = 'video'
      if endsWith(texture, '.webm')
        video.type = 'video/webm'
      else
        video.type = 'video/mp4'
      video.src = texture
      video.loop = true
      video.load()
      video.play()

      videoImage = document.createElement('canvas');
      videoImage.width = 720
      videoImage.height = 360

      videoImageContext = videoImage.getContext('2d')
      videoImageContext.fillStyle = '#000000';
      videoImageContext.fillRect(0, 0, videoImage.width, videoImage.height);

      videoTexture = new THREE.Texture(videoImage);
      videoTexture.minFilter = THREE.LinearFilter;
      videoTexture.magFilter = THREE.LinearFilter;

      @sphere.material = new THREE.MeshBasicMaterial
        map: videoTexture
        overdraw: true
      @_setLoading false
    else
      imageTexture = THREE.ImageUtils.loadTexture src, undefined, =>
        @renderer?.render(@scene, @camera)
        @_setLoading false
      imageTexture.minFilter = THREE.LinearFilter

      @sphere.material = new THREE.MeshBasicMaterial
        map: imageTexture

  fovChanged: (fov) ->
    @camera.fov = fov
    @camera.updateProjectionMatrix()
    @_dirty = yes

  rotateChanged: (rotate) ->
    @controls?.autoRotate = rotate

  stereoChanged: (stereo) ->
    @actualRenderer = if @stereo then @stereoEffect else @renderer
    @actualRenderer.setSize(@clientWidth, @clientHeight)
    @_dirty = yes

  _gyroSensor: (ev) ->
    eyem = new THREE.Quaternion().setFromEuler(new THREE.Euler(-Math.PI / 2, 0, 0))
    d2r = Math.PI / 180

    angle = getOrientation();
    alpha = ev.alpha || 0;
    beta = ev.beta || 0;
    gamma = ev.gamma || 0;
    return if alpha == 0 && beta == 0 && gamma == 0

    # device rot axis order Z-X-Y as alpha, beta, gamma
    # portrait mode Z=rear->front(screen), X=left->right, Y=near->far(cam)
    # => map Z-X-Y to 3D world axes as:
    # - portrait  => y-x-z
    # - landscape => y-z-x
    rotType = if angle == 0 or angle == 180 then "YXZ" else "YZX";
    rotm = new THREE.Quaternion().setFromEuler(new THREE.Euler(beta * d2r, alpha * d2r, -gamma * d2r, rotType))
    devm = new THREE.Quaternion().setFromEuler(new THREE.Euler(0, -angle * d2r, 0))
    rotm.multiply(devm).multiply(eyem)
    @camera.quaternion.copy(rotm)
    @_dirty = yes

  gyroscopeChanged: (gyroEnabled) ->
    if gyroEnabled
      @controls?.enabled = no
      if window.DeviceOrientationEvent
        @_gyroWrapper = (e) => @_gyroSensor(e) #call _gyroSensor with correct `this`
        window.addEventListener("deviceorientation", @_gyroWrapper, false)
    else
      @controls?.enabled = yes
      window.removeEventListener("deviceorientation", @_gyroWrapper, false)

    @controls?.noRotate = gyroEnabled
    @controls?.autoRotate = @rotate && !gyroEnabled

  rotateXChanged: (x) ->
    @camera.rotation.x = x
    @_dirty = yes

  rotateYChanged: (y) ->
    @camera.rotation.y = y
    @_dirty = yes

  rotateZChanged: (z) ->
    @camera.rotation.z = z
    @_dirty = yes

  onMouseWheel: (event) ->
    delta = 0
    if (event.wheelDeltaY)  # WebKit
      delta = -event.wheelDeltaY * 0.05;
    else if (event.wheelDelta) # Opera / IE9
      delta = -event.wheelDelta * 0.05;
    else if (event.detail)  # Firefox
      delta = event.detail * 1.0

    @fov = Math.max(40, Math.min(100, @fov + delta))

  _onIronResize: ->
    if @offsetWidth > 0 and @offsetHeight > 0
      @actualRenderer.setSize(@offsetWidth, @offsetHeight)
      @camera.aspect = @offsetWidth / @offsetHeight
      @camera.updateProjectionMatrix()
      @_dirty = yes