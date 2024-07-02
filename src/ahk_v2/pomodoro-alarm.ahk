#Requires AutoHotkey v2.0
#SingleInstance Force
#NoTrayIcon
SetTitleMatchMode 1

; 定义工作和休息时间（以毫秒为单位）
k := 1
work_time := 20 * k * 1000       ; 20分钟
short_rest_time := 5 * k * 1000  ; 5分钟
long_rest_time := 30 * k * 1000  ; 30分钟
flash_increment := 5 * 1 * 1000  ; 5秒

state_file := A_Temp "\pomodoro-state.ini"
dryrun := False                   ; 默认为False，设置为True进行dryrun测试

class Phase_State {
    ; 构造函数，初始化状态对象
    __New(ini_path, work_duration, short_rest_duration, long_rest_duration) {
        this.ini_file := ini_path
        this.LastEventTime := A_Now
        this.Mode := "work"
        this.PomodoroCount := 0
        this.AccumulatedTime := 0
        this.RestTime := 5 * 60 * 1000
        this.WorkDuration := work_duration
        this.ShortRestDuration := short_rest_duration
        this.LongRestDuration := long_rest_duration
        this.Counter := SecondCounter(1)
        this.Load

    }


    ; 增加计数器
    IncrementAccumulated(increment, save := false) {
        this.AccumulatedTime += increment
        if save {
            this.Save()
        }
    }

    ; 读取事件时间
    ReadLastEventTime() {
        this.LastEventTime := IniRead(this.ini_file, "State", "LastEventTime", A_Now)
        return this.LastEventTime
    }

    ; 在两种模式之间切换
    ToggleMode() {
        this.mode := (this.mode = "work") ? "rest" : "work"
        this.AccumulatedTime := 0
        this.LastEventTime := A_Now
        OutputDebug Format("ToggleMode = {}", this.mode)
        return this.mode
    }

    ; 切换到指定模式
    SwitchMode(targe_mode, save_ini := false) {
        this.mode := targe_mode
        this.AccumulatedTime := 0
        this.LastEventTime := A_Now
        if (save_ini) {
            this.Save()
        }
    }

    ; 现在到事件时间(内存)的间隔
    GetTimeDelta_sec() {
        return DateDiff(A_Now, this.LastEventTime, "Seconds")
    }

    ; 现在到事件时间(log)的间隔
    GetLogTimeDelta_sec() {
        temp_LastEventTime := IniRead(this.ini_file, "State", "LastEventTime", A_Now)
        return DateDiff(A_Now, temp_LastEventTime, "Seconds")
    }

    ; 增加番茄循环次数 如果参数-1，则置零
    IncrementPomodoroCount(increment := 1) {
        this.PomodoroCount := (increment = -1) ? 0 : Mod(this.PomodoroCount + increment, 4)
    }

    ; 从文件加载状态
    Load(attributes*) {
        ; 默认属性列表
        default_attributes := ["LastEventTime", "Mode", "PomodoroCount", "AccumulatedTime", "RestTime"]
        attributes := (attributes.Length > 0) ? attributes : default_attributes

        for item in attributes {
            if (InArray(default_attributes, item))
                this.%item% := IniRead(this.ini_file, "State", item, "")
        }
    }

    ; 保存状态到文件
    Save(attributes*) {
        ; 默认属性列表
        default_attributes := ["LastEventTime", "Mode", "PomodoroCount", "AccumulatedTime", "RestTime"]
        attributes := (attributes.Length > 0) ? attributes : default_attributes

        for item in attributes {
            if (InArray(default_attributes, item)) {
                value := this.%item%
                IniWrite(value, this.ini_file, "State", item)
            }
        }
    }

    ; 初始化
    Initialize(attributes*) {
        ; 默认属性列表
        default_attributes := ["LastEventTime", "Mode", "PomodoroCount", "AccumulatedTime", "RestTime"]
        attributes := (attributes.Length > 0) ? attributes : default_attributes

        for item in attributes {
            if (InArray(default_attributes, item)) {
                if (item = "LastEventTime") {
                    value := A_Now
                } else if (item = "Mode") {
                    value := "work"
                } else {
                    value := 0
                }
                IniWrite(value, this.ini_file, "State", item)
            }
        }
    }

    ; 返回持续时间
    GetModeDuration(mode := "") {
        mode := (mode = "") ? this.Mode : mode

        switch mode {
            case "work":
                return this.WorkDuration
            case "rest":
                return (this.PomodoroCount == 3) ? this.LongRestDuration : this.ShortRestDuration
            default:
                return 60 * 1000  ; 默认情况下返回 60 秒的持续时间
        }

    }
}

class SecondCounter {
    __New(interval_sec) {
        this.interval := interval_sec * 1000
        this.count := 0
        this.paused := false
        ; Tick() 有一个隐式参数 "this", 其引用一个对象
        ; 所以, 我们需要创建一个封装了 "this " 和调用方法的函数:
        this.timer := ObjBindMethod(this, "Tick")
    }
    Start() {
        if this.paused {
            this.Reset()
            this.Resume()
        } else {
            SetTimer this.timer, this.interval
            OutputDebug "Counter started at " this.count
        }
    }
    Stop() {
        ; 要关闭计时器, 我们必须传递和之前一样的对象:
        SetTimer this.timer, 0
        OutputDebug "Counter stopped at " this.count
        this.paused := false
    }
    Pause() {
        SetTimer this.timer, 0
        OutputDebug "Counter paused at " this.count
        this.paused := true
    }
    Resume() {
        SetTimer this.timer, this.interval
        OutputDebug "Counter resumed at " this.count
    }
    Reset() {
        this.count := 0
        OutputDebug "Counter reset, Now count = " this.count
    }
    GetCount() {
        OutputDebug "GetCount = " this.count
        return this.count
    }
    ; 本例中, 计时器调用了以下方法:
    Tick() {
        OutputDebug Format("timer {}", ++this.count)
        return this.count
    }
}

state := Phase_State(state_file, work_time, short_rest_time, long_rest_time)
; 存储在内存中的状态
state_in_ram := Phase_State(state_file, work_time, short_rest_time, long_rest_time)

Nothing(*) {
    ; 什么也不做的回调函数
}

InArray(Haystack, Needle) {
    if !isObject(Haystack)
        return false
    if Haystack.Length == 0
        return false
    for index, value in Haystack
        if (value == Needle)
            return index
    return false
}

; 显示休息提示屏幕
; ShowRestScreen() {
;     alarm_window_handle := Object()
;     countdown_handle := Object()

;     restTime := ((state.PomodoroCount == 3) ? long_rest_time : short_rest_time)
;     duration := restTime - state.AccumulatedTime
;     if not WinExist("Pomodoro alarm clock") {
;         OutputDebug "not found"
;         CreateCountdownWindow(duration, &alarm_window_handle, &countdown_handle)
;         ; SetTimer(UpdateCountdown)
;     }
; }

; CreateCountdownWindow(duration, &window_handle, &control_handle) {
;     global state
;     total_seconds := (duration - state.AccumulatedTime) / 1000
;     local_total_seconds := total_seconds

;     MonitorGet(, &Left, &Top, &W, &H)
;     window_handle := Gui()
;     window_handle.Opt("-MinimizeBox -MaximizeBox -SysMenu Disabled AlwaysOnTop +Owner")
;     window_handle.Title := "Pomodoro alarm clock"
;     window_handle.BackColor := "c2f343a"

;     window_handle.SetFont("s60 q1 c49505a", "微软雅黑")
;     remind_text := window_handle.Add("Text", Format("w{1} r1 Center", W * 0.8), "    中场暂停！！")
;     window_handle.SetFont("s100 q1 cd1cbab", "Tahoma")
;     time_count := window_handle.Add("Text", Format("w{1} r2 Center", W * 0.8), "MM : SS")

;     window_handle.Show()

;     restTime := (state.PomodoroCount == 3) ? long_rest_time : short_rest_time

;     loop {
;         minutes := Floor(local_total_seconds / 60)
;         seconds := Mod(local_total_seconds, 60)
;         time_count.Text := Format("{:02d} : {:02d}", minutes, seconds)

;         total_seconds := (duration - state.AccumulatedTime) / 1000

;         if (DateDiff(A_Now, state.LastEventTime, "Seconds")) > restTime / 1000 {
;             state.mode := "work"
;             state.AccumulatedTime := 0
;             state.LastEventTime := A_Now
;             SaveState(&state)
;             break
;         }

;         if local_total_seconds <= 0
;             break

;         Sleep 1000
;         local_total_seconds -= 1
;     }
;     window_handle.Destroy
; }


; GPT

; 定时器函数：每秒钟增加累积时间并检查是否需要切换模式
IncrementAndCheckMode() {
    global state
    mode_duration_threshold := state.GetModeDuration()

    ; 达到一定时间切换模式
    if (state.AccumulatedTime >= mode_duration_threshold) {
        state.Initialize("LastEventTime,AccumulatedTime")  ; 初始化状态
        state.ToggleMode()  ; 切换模式
        OutputDebug "State reset and mode toggled."
    }
    state.IncrementAccumulated(1000, true)  ; 每秒增加1秒累积时间
}

; 定时器函数：每分钟检查时间差异并根据条件重置状态
HandleTimeDifference() {
    global state
    time_delta_sec := state.GetTimeDelta_sec()
    log_time_delta_sec := state.GetLogTimeDelta_sec()
    mode_duration_threshold := state.GetModeDuration("rest")


    ; 如果时间差异大于休息阈值，则重置状态
    if ((log_time_delta_sec - state.AccumulatedTime / 1000) > mode_duration_threshold / 1000) {
        state.Initialize("LastEventTime", "AccumulatedTime")  ; 初始化状态
        state.Mode := "work"  ; 切换到工作模式
        state.Save(["LastEventTime", "Mode", "AccumulatedTime"])  ; 保存状态
        OutputDebug("State reset and mode switched to 'work' due to large time difference.")
    }
}

; 创建定时器：每秒钟调用 IncrementAndCheckMode 函数
SetTimer(IncrementAndCheckMode, flash_increment)

; 创建定时器：每分钟调用 HandleTimeDifference 函数
SetTimer(HandleTimeDifference, 60000)

; 定时器函数：休息模式下的倒计时窗口
; RestModeCountdown() {
;     global state
;     if (state.Mode = "rest" && !GuiExist("TimerWindow")) {
;         Gui, TimerWindow: New
;         Gui, TimerWindow: Add, Text, Center y20 w200 h50 vTimeLeft, Rest Time Left:
;             Gui, TimerWindow: Show, NoActivate
;         SetTimer(Func("UpdateRestTimeLeft"), 1000)
;     } else if (obj.Mode != "rest" && GuiExist("TimerWindow")) {
;         Gui, TimerWindow: Destroy
;     }
; }

; 更新休息时间剩余
; UpdateRestTimeLeft() {
;     rest_duration := 300  ; 休息时长，这里假设为5分钟，单位为秒
;     elapsed_time := DateDiff(A_Now, obj.LastEventTime, "Seconds")
;     time_left := Max(0, rest_duration - elapsed_time)

;     GuiControl, , TimeLeft, Rest Time Left: `n%duration% seconds

;     if (time_left <= 0) {
;         SetTimer(Func("UpdateRestTimeLeft"), Off)
;         MsgBox("Rest time is over.")
;         obj.ToggleMode()  ; 自动切换回工作模式
;     }
; }

; ; 创建定时器：每秒钟调用 RestModeCountdown 函数
; SetTimer(Func("RestModeCountdown"), 1000)


; Main() {
;     global state
;     ; 4小时重置番茄循环
;     time_diffrence := state.GetLogTimeDelta_sec()
;     if time_diffrence >= 4 * 3600 {
;         state.Initialize()
;     }
;     state.PomodoroCount := (time_diffrence >= 4 * 3600) ? 0 : state.PomodoroCount

;     ; 未满4小时的循环逻辑
;     restTime := (state.PomodoroCount == 3) ? long_rest_time : short_rest_time
;     if state.mode = "work" {
;         if (time_diffrence >= state.AccumulatedTime + restTime) {
;             state.Initialize("LastEventTime")
;             state.PomodoroCount := Mod((state.PomodoroCount + 1), 4)
;             state.Save
;         }
;     }

;     if state.mode = "rest" {
;         if (time_diffrence >= restTime) {
;             state.Initialize("LastEventTime")
;             state.PomodoroCount := Mod((state.PomodoroCount + 1), 4)
;             state.Save
;             OutputDebug Format("【已休息{6}分钟】{1}: line({2}) 计时器 = {3}, mode = {4}, count = {5}", A_Now, A_LineNumber, state.AccumulatedTime / 1000, state.mode, state.PomodoroCount, state.AccumulatedTime)
;         }
;     }


; }

; Main()
