function love.conf(t)
    local mobile=love._os=='Android'

    t.identity='SmartBingo'
    t.externalstorage=true
    t.version="11.5"
    t.gammacorrect=false
    t.appendidentity=true
    t.accelerometerjoystick=false
    if t.audio then
        t.audio.mic=false
        t.audio.mixwithsystem=true
    end

    local M=t.modules
    M.window,M.system,M.event,M.thread=true,true,true,true
    M.timer,M.math,M.data=true,true,true
    M.video,M.audio,M.sound=true,true,true
    M.graphics,M.font,M.image=true,true,true
    M.mouse,M.touch,M.keyboard,M.joystick=true,true,true,true
    M.physics=false

    local W=t.window
    W.vsync=0
    W.msaa=2
    W.depth=0
    W.stencil=1
    W.display=1
    W.highdpi=true
    W.x,W.y=nil,nil
    W.borderless=mobile
    W.resizable=not mobile
    W.fullscreentype=mobile and 'exclusive' or 'desktop'
    if mobile then
        W.width,W.height=900,1440
        W.minwidth,W.minheight=180,288
    else
        W.width,W.height=1440,900
        W.minwidth,W.minheight=288,180
    end
    W.title='Smart Bingo v1.0'
end
