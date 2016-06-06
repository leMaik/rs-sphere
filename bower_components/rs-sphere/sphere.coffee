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
      notify: true
      readOnly: true
    src:
      type: String
      reflectToAttribute: true
      observer: 'sourceChanged'
    srcRight:
      type: String
      reflectToAttribute: true
      observer: 'sourceRightChanged'
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
    @scene = new THREE.Scene();

    @sphere = new THREE.Mesh(new THREE.SphereGeometry(100, 32, 32))
    @sphere.scale.x = -1
    @sphere.visible = no

    @sphereR = new THREE.Mesh(new THREE.SphereGeometry(100, 32, 32))
    @sphereR.position.x = 200
    @sphereR.scale.x = -1
    @sphereR.visible = no

    @scene.add @sphere
    @scene.add @sphereR
    @scene.add(new THREE.AmbientLight(0x333333))

    @views = [
      {
        left: 0,
        bottom: 0,
        width: 0.5,
        height: 1.0,
        eye: [ 0, 0, 1.5 ],
        up: [ 0, 1, 0 ],
        fov: 75
      },
      {
        left: 0.5,
        bottom: 0,
        width: 0.5,
        height: 1.0,
        eye: [ 200, 0, 1.5 ],
        up: [ 0, 1, 0 ],
        fov: 75
      }
    ]

    for view in @views
      camera = new THREE.PerspectiveCamera(view.fov, 0, 1, 1000)
      camera.position.x = view.eye[0]
      camera.position.y = view.eye[1]
      camera.position.z = view.eye[2]
      camera.up.x = view.up[0]
      camera.up.y = view.up[1]
      camera.up.z = view.up[2]
      view.camera = camera

    @renderer = if webgl then new THREE.WebGLRenderer() else new THREE.CanvasRenderer()
    #@stereoEffect = new THREE.StereoEffect(@renderer)
    @actualRenderer = @renderer

    @_dirty = yes

  attached: ->
    @controls = new THREE.OrbitControls(@views[0].camera, @$.webgl)
    @controls.noPan = on
    @controls.noZoom = on
    @controls.noRotate = @gyroscope
    @controls.autoRotate = @rotate && !@gyroscope
    @controls.autoRotateSpeed = 0.5
    @controls.addEventListener 'change', =>
      @rotateX = @views[0].camera.rotation.x
      @rotateY = @views[0].camera.rotation.y
      @rotateZ = @views[0].camera.rotation.z
      @_dirty = yes

    @render = =>
      if video?
        if video.readyState is video.HAVE_ENOUGH_DATA
          videoImageContext.drawImage(video, 0, 0)
          if (videoTexture)
            videoTexture.needsUpdate = true
      
      if @stereo
        for view in @views
          camera = view.camera
          camera.updateMatrixWorld()
          windowWidth  = window.innerWidth
          windowHeight = window.innerHeight
          left   = Math.floor( windowWidth  * view.left )
          bottom = Math.floor( windowHeight * view.bottom )
          width  = Math.floor( windowWidth  * view.width )
          height = Math.floor( windowHeight * view.height )
          @renderer.setViewport( left, bottom, width, height )
          @renderer.setScissor( left, bottom, width, height )
          @renderer.setScissorTest( true )
          @renderer.setClearColor( view.background )
          camera.aspect = width / height
          camera.updateProjectionMatrix()
          @renderer.render(@scene, camera)
      else
          camera = @views[0].camera
          camera.updateMatrixWorld()
          windowWidth  = window.innerWidth
          windowHeight = window.innerHeight
          @renderer.setViewport( 0, 0, windowWidth, windowHeight )
          @renderer.setScissor( 0, 0, windowWidth, windowHeight )
          @renderer.setScissorTest( true )
          camera.aspect = windowWidth / windowHeight
          camera.updateProjectionMatrix()
          @renderer.render(@scene, camera)        

    animate = =>
      if not this.gyroscope
        @controls.update()
      if @_dirty #TODO always dirty if we play a video
        @_dirty = no
        @render()
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
    @sphere.visible = no

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
      if @sphereR.visible
        @_setLoading false
      @sphere.visible = yes
      @_dirty = yes
    else
      loader = new THREE.TextureLoader()
      loader.crossOrigin = ''
      loader.load src, (texture) =>
        texture.minFilter = THREE.LinearFilter
        @sphere.material = new THREE.MeshBasicMaterial
          map: texture
        if @render
          @render()
        if @sphereR.visible
          @_setLoading false
        @sphere.visible = yes
        @_dirty = yes

  sourceRightChanged: (src) ->
    @_setLoading true
    @sphereR.visible = no

    texture = @srcRight
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
      # TODO synchronize left and right video

      videoImage = document.createElement('canvas');
      videoImage.width = 720
      videoImage.height = 360

      videoImageContext = videoImage.getContext('2d')
      videoImageContext.fillStyle = '#000000';
      videoImageContext.fillRect(0, 0, videoImage.width, videoImage.height);

      videoTexture = new THREE.Texture(videoImage);
      videoTexture.minFilter = THREE.LinearFilter;
      videoTexture.magFilter = THREE.LinearFilter;

      @sphereR.material = new THREE.MeshBasicMaterial
        map: videoTexture
        overdraw: true
      if @sphere.visible
        @_setLoading false
      @sphereR.visible = yes
      @_dirty = yes
    else
      loader = new THREE.TextureLoader()
      loader.crossOrigin = ''
      loader.load 'right.png', (texture) =>
        texture.minFilter = THREE.LinearFilter
        @sphereR.material = new THREE.MeshBasicMaterial
          map: texture
        if @render
          @render()
        if @sphere.visible
          @_setLoading false
        @sphereR.visible = yes
        @_dirty = yes

  fovChanged: (fov) ->
    for view in @views
      view.camera.fov = fov
      view.camera.updateProjectionMatrix()
    @_dirty = yes

  rotateChanged: (rotate) ->
    @controls?.autoRotate = rotate

  stereoChanged: (stereo) ->
    @renderer.setSize(@clientWidth, @clientHeight)
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

    for view in @views
      view.camera.quaternion.copy(finalQuaternion)
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
    for view in @views
      view.camera.rotation.x = x
    @_dirty = yes

  rotateYChanged: (y) ->
    for view in @views
      view.camera.rotation.y = y
    @_dirty = yes

  rotateZChanged: (z) ->
    for view in @views
      view.camera.rotation.z = z
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
      for view in @views
        view.camera.aspect = @offsetWidth / @offsetHeight
        view.camera.updateProjectionMatrix()
      @_dirty = yes
