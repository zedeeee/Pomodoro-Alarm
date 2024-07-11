#Requires AutoHotkey v2.0
#SingleInstance Force
#NoTrayIcon
SetTitleMatchMode 1

; 定义工作和休息时间（以毫秒为单位）
k := 60
work_time := 20 * k       ; 20分钟
short_rest_time := 5 * k  ; 5分钟
long_rest_time := 30 * k  ; 30分钟
flash_increment := 2 * 1000  ; ms
login_time_interval := 7 * 1000        ; ms

state_file := A_Temp "\pomodoro-state.ini"
alarm_tag := "Pomodoro alarm clock"

/**
 * 1. 获取当前阶段状态
 * 2. 获取累积时间
 * 3. 从文件加载信息(全部或者指定)
 * 4. 将信息写入到文件
 * 5. 获取循环次数
 * 
 * @param ini_path  存放状态的路径
 * @param work_duration
 * @param short_rest_duration
 * @param long_rest_duration
 * @param name object name
 * 
 * @retun object
 * 
 */
class Phase {
    ; 构造函数，初始化状态对象
    __New(ini_path, work_duration, short_rest_duration, long_rest_duration, obj_name) {
        this.ini_file := ini_path
        this.LastEventTime := "uninit"
        this.Mode := "uninit"
        this.PomodoroCount := "uninit"
        this.AccumulatedTime := "uninit"
        this.DurationThreshold := "uninit"
        this.WorkDuration := work_duration
        this.ShortRestDuration := short_rest_duration
        this.LongRestDuration := long_rest_duration
        this.Name := obj_name
    }

    ; 读取事件时间 from ini file
    ReadLastEventTime() {
        this.LastEventTime := IniRead(this.ini_file, "State", "LastEventTime", A_Now)
        OutputDebug this.LastEventTime
        return this.LastEventTime
    }

    ; 切换状态，并重置记录数据
    ; 影响属性：AccumulatedTime, Mode, PomodoroCount, DurationThreshold
    Toggle() {
        ; 将模式交换
        this.Mode := (this.Mode = "work") ? "rest" : "work"
        this.Initialize("LastEventTime", "AccumulatedTime")
        this.CalculateDurationThreshold()
        if (this.Mode = "work") {
            this.PomodoroCount := Mod((this.PomodoroCount + 1), 4)
        }
        OutputDebug "Mode changed to " this.Mode

    }

    ; 切换到指定模式
    Switch(target_mode) {
        if (this.Mode != target_mode) {
            this.Toggle()
        }
    }

    ; 根据持续时间设置状态
    ; 根据时间间隔决定是否应该切换状态
    AutoDecideState() {
        ; 获取从上次事件到现在的时间间隔
        time_diffrence := this.GetTimeDelta_sec()

        ; 如果间隔 > 2h ，进入全新计时，并保存当前状态
        if time_diffrence >= 2 * 60 * 60 {
            this.Initialize()
            this.Save
            OutputDebug "大于2小时，进入全新计时"
            return
        }

        if this.AccumulatedTime >= this.DurationThreshold {
            OutputDebug Format("已达到{}阈值{}，正在切出状态", this.Mode, this.DurationThreshold, this.Mode)
            this.Toggle()
            this.Save()
            return
        }

        restTime := (this.PomodoroCount == 3) ? this.LongRestDuration : this.ShortRestDuration

        ; 如果工作阶段还没完成就开始休息，且休息时长满足要求
        ; 则直接进去下一轮工作时间, 否则继续保持目前状态
        if this.mode = "work" {
            if (time_diffrence - this.AccumulatedTime >= restTime) {
                this.Initialize("LastEventTime", "AccumulatedTime")
                this.DurationThreshold := this.WorkDuration
                if this.AccumulatedTime / this.DurationThreshold >= 0.5 {
                    this.IncrementPomodoroCount()
                }
                this.Save()
                OutputDebug "已满足休息时长，跳过本轮工作，进入新一轮工作"
            } else {
                OutputDebug Format("未满足时长，继续本轮{2}, 已持续 {3}/{1} 秒", this.DurationThreshold, this.Mode, this.AccumulatedTime)
            }
        }

        ; 如果当前是休息阶段，且休息时长满足要求
        ; 则直接进去下一轮工作时间, 否则继续保持目前状态
        if this.mode = "rest" {
            this.DurationThreshold := restTime
            if (time_diffrence - this.AccumulatedTime >= restTime) {
                this.Switch("work")
                this.Save
                OutputDebug "已满足休息时长，进入新一轮工作"
            } else {
                ; this.LastEventTime := DateAdd(A_Now, -this.DurationThreshold, "Seconds")
                OutputDebug Format("未满足时长，继续本轮{2}, 已持续 {3}/{1} 秒", this.DurationThreshold, this.Mode, this.AccumulatedTime)
            }
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

    ; 从ini文件更新最后一次事件时间到内存
    UpdateLastEventTime() {
        this.LastEventTime := IniRead(this.ini_file, "State", "LastEventTime", A_Now)
        return this.LastEventTime
    }

    ; 增加番茄循环次数 如果参数-1，则置零
    IncrementPomodoroCount(increment := 1) {
        this.PomodoroCount := (increment = -1) ? 0 : Mod(this.PomodoroCount + increment, 4)
    }

    ; 增加累计时间（内存）
    IncrementAccumulatedTime() {
        this.AccumulatedTime := this.GetTimeDelta_sec()
        OutputDebug this.AccumulatedTime
    }

    ; 从文件加载状态, 如果没有则使用默认值
    Load(attributes*) {
        ; 默认属性列表
        default_attributes := ["LastEventTime", "Mode", "PomodoroCount", "AccumulatedTime"]
        attributes := (attributes.Length > 0) ? attributes : default_attributes

        for item in attributes {
            if (InArray(default_attributes, item)) {
                switch item {
                    case "LastEventTime":
                        value := A_Now
                    case "Mode":
                        value := "work"
                    default:
                        value := 0
                }
                this.%item% := IniRead(this.ini_file, "State", item, value)
            }
        }
    }

    ; 保存状态到文件
    Save(attributes*) {
        ; 默认属性列表
        default_attributes := ["LastEventTime", "Mode", "PomodoroCount", "AccumulatedTime"]
        attributes := (attributes.Length > 0) ? attributes : default_attributes

        for item in attributes {
            if (InArray(default_attributes, item)) {
                IniWrite(this.%item%, this.ini_file, "State", item)
            }
        }
    }

    ; 状态清零，进入新的一轮番茄计时器（用于首次或者大于2小时的时间间隔）
    Initialize(attributes*) {

        ; 状态属性清零
        default_attributes := ["LastEventTime", "Mode", "PomodoroCount", "AccumulatedTime"]
        attributes := (attributes.Length > 0) ? attributes : default_attributes

        for item in attributes {
            if (InArray(default_attributes, item)) {
                switch item {
                    case "LastEventTime":
                        value := A_Now
                    case "Mode":
                        value := "work"
                    default:
                        value := 0
                }
                this.%item% := value
            }
        }

        this.CalculateDurationThreshold()
        ; this.AutoDecideState()

        ; 重置计时器
        ; this.Counter.Name := this.Name
        ; this.Counter.Initialize()
    }

    ; 根据阶段计算状态的持续阈值时间
    ; 如果输入参数为空，则计算当前所处状态的持续阈值时间
    CalculateDurationThreshold(mode := "") {
        mode := (mode = "") ? this.Mode : mode
        rest_time := (this.PomodoroCount == 3) ? long_rest_time : short_rest_time

        switch mode {
            case "work":
                this.DurationThreshold := this.WorkDuration
            case "rest":
                this.DurationThreshold := rest_time
            default:
                this.DurationThreshold := 60  ; 默认情况下返回 60 秒的持续时间
        }
    }
}

/**
 * 
 */
class Counter {
    __New(interval_sec, counter_name, targetObject, targetMethod) {
        this.interval_ms := interval_sec * 1000
        this.count := 0
        this.paused := false
        this.IsRunning := false
        this.Name := counter_name
        this.targetObject := targetObject
        this.targetMethod := targetMethod
        ; Tick() 有一个隐式参数 "this", 其引用一个对象
        ; 所以, 我们需要创建一个封装了 "this " 和调用方法的函数:
        this.timer := ObjBindMethod(this, "Tick")
        this.Start()
    }
    Start() {
        if this.paused {
            this.Reset()
            this.Resume()
        } else {
            SetTimer this.timer, this.interval_ms
            this.IsRunning := true
            OutputDebug this.name " started at " this.count
        }
    }
    Stop() {
        ; 要关闭计时器, 我们必须传递和之前一样的对象:
        SetTimer this.timer, 0
        OutputDebug this.name " stopped at " this.count
        this.Reset()
        this.paused := false
        this.IsRunning := false
    }
    Pause() {
        SetTimer this.timer, 0
        OutputDebug this.name " paused at " this.count
        this.paused := true
    }
    Resume() {
        if this.paused {
            SetTimer this.timer, this.interval_ms
            OutputDebug this.name " resumed at " this.count
        }
        else {
            OutputDebug this.name " resumed false, paused = " this.paused
            return false
        }
    }
    Set(new_count_sec) {
        this.count := new_count_sec
        OutputDebug this.name " set, Now count = " this.count
    }

    Reset() {
        this.Set(0)
        OutputDebug this.name " reset, Now count = " this.count
    }
    GetCount() {
        OutputDebug this.name " GetCount = " this.count
        return this.count
    }
    Initialize() {
        this.Stop()
        this.Reset()
        this.Start()
    }
    ; 本例中, 计时器调用了以下方法:
    Tick() {
        OutputDebug Format("{} timer {}", this.name, ++this.count)
        return this.count
    }

    TriggerAction() {
        this.targetObject.%this.targetMethod%()
    }
}

/**
 * 事件时间提示器
 * 每隔 10 秒检查 ini 文件中的事件时间是否异常
 */
class TimeDiffer {
    LastEventTime := A_Now
    __New(file_path, callback) {
        this.FilePath := file_path
        this.CallBack := callback
        SetTimer(this.CheckTime.Bind(this), 1000)
    }

    CheckTime() {
        log_last_event_time := IniRead(this.FilePath, "State", "LastEventTime", A_Now)
        if (log_last_event_time != this.LastEventTime) {
            ; this.LastEventTime := log_last_event_time
            this.callback()
            OutputDebug "检查到事件时间差异"
            ; if !this.callback
            ;     MsgBox("事件时间更新失败")
        }
    }

    Stop() {
        SetTimer(this.CheckTime, 0)
    }
}

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

class CountdownWindow {
    ; __New(duration, window_handle, control_handle) {

    __New(window_title) {
        this.WindowTitle := window_title
        this.WindowHandle := ""
        this.ControlHandle := ""
        this.Initialize()
    }

    Initialize() {
        MonitorGet(, &Left, &Top, &W, &H)

        ; 窗口部分
        this.WindowHandle := Gui()
        this.WindowHandle.Opt("-MinimizeBox -MaximizeBox -SysMenu Disabled +Owner")
        ; this.WindowHandle.Opt("-MinimizeBox -MaximizeBox -SysMenu Disabled AlwaysOnTop +Owner")
        this.WindowHandle.Title := this.WindowTitle
        this.WindowHandle.BackColor := "c2f343a"

        ; 文字部分
        this.WindowHandle.SetFont("s60 q1 c49505a", "微软雅黑")
        this.WindowHandle.Add("Text", Format("w{1} r1 Center", W * 0.8), "    休息，休息一下！！")
        this.WindowHandle.SetFont(Format("s{} q1 cd1cbab", W * 0.1), "Tahoma")
        this.ControlHandle := this.WindowHandle.Add("Text", Format("w{1} r1 Center", W * 0.8), "MM : SS")
        this.WindowHandle.SetFont("s60 q1 c49505a", "微软雅黑")
        this.WindowHandle.Add("Text", Format("w{1} r1 Center", W * 0.8), "")

    }

    Show() {
        this.WindowHandle.Show()
    }

    Hide() {
        this.WindowHandle.Hide()
    }

    Start() {
        ; 休息提示屏幕
    }

    Stop() {
        this.WindowHandle.Destroy
    }

    Set(num_sec) {
        ; 以下三行代码将秒转换成 mm:ss 格式字符串
        time := 19990101  ; 任意日期的 *午夜*.
        time := DateAdd(time, num_sec, "Seconds")
        this.ControlHandle.Text := FormatTime(time, "mm:ss")
    }

    UpdateCountdown() {
        ; 休息提示屏幕
    }
    info() {
        OutputDebug "CountdownWindow: "
    }

}

Main() {
    pomodoro_phase := Phase(state_file, work_time, short_rest_time, long_rest_time, "P-alarm")
    pomodoro_phase.Initialize()
    pomodoro_phase.Load()
    pomodoro_phase.AutoDecideState()

    ; 定时器函数：每秒钟获取真时间差，并检查是否需要切换模式
    SetTimer(pomodoro_phase.AutoDecideState.Bind(pomodoro_phase), flash_increment)

    ; 定时增加累积时间
    SetTimer(pomodoro_phase.IncrementAccumulatedTime.Bind(pomodoro_phase), 1000)

    ; 定时写入日志
    SetTimer(pomodoro_phase.Save.Bind(pomodoro_phase), login_time_interval)

    CDW := CountdownWindow(alarm_tag)
    loop {
        if pomodoro_phase.mode = "rest" {
            CDW.Show()
            time_left := pomodoro_phase.DurationThreshold - pomodoro_phase.AccumulatedTime
            if time_left >= 0 {
                CDW.Set(time_left)
            } else {
                CDW.Hide()
            }
        } else {
            CDW.Hide()
        }
        Sleep 1000
    }
}

Main()