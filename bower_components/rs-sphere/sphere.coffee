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

Polymer
  is: 'rs-sphere'
  properties:
    loading:
      type: Boolean
      value: false
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
    # all credits for this function go to richtr
    # https://github.com/richtr/threeVR/blob/master/js/DeviceOrientationController.js

    alpha  = THREE.Math.degToRad( ev.alpha || 0 ); # Z
    beta   = THREE.Math.degToRad( ev.beta  || 0 ); # X'
    gamma  = THREE.Math.degToRad( ev.gamma || 0 ); # Y''
    orient = THREE.Math.degToRad( window.orientation           || 0 ); # O

    # only process non-zero 3-axis data
    return if alpha is 0 or beta is 0 or gamma is 0

    finalQuaternion = new THREE.Quaternion()
    deviceEuler = new THREE.Euler()
    screenTransform = new THREE.Quaternion()
    worldTransform = new THREE.Quaternion(-Math.sqrt(0.5), 0, 0, Math.sqrt(0.5)) # - PI/2 around the x-axis
    deviceEuler.set( beta, alpha, - gamma, 'YXZ' );
    finalQuaternion.setFromEuler( deviceEuler );
    minusHalfAngle = -orient / 2;
    screenTransform.set( 0, Math.sin( minusHalfAngle ), 0, Math.cos( minusHalfAngle ) );
    finalQuaternion.multiply( screenTransform );
    finalQuaternion.multiply( worldTransform );

    @camera.quaternion.copy(finalQuaternion)
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
