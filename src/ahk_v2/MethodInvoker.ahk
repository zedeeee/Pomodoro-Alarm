/************************************************************************
 * @description 这个脚本的主要功能是创建一个计时器，
 *              在设定时间后触发指定对象的方法。
 * @file MethodInvoker.ahk
 * @author 
 * @date 2024/07/07
 * @version 0.1.0
 ***********************************************************************/

#Requires AutoHotkey v2.0
#SingleInstance Force

class Timer {
    Count := 0
    __New(seconds, targetObject, targetMethod) {
        this.seconds := seconds
        this.targetObject := targetObject
        this.targetMethod := targetMethod
        this.Start()
        ; this.PrintCount()
    }

    Start() {
        ; 将秒数转换为毫秒
        delay := this.seconds * 1000
        SetTimer(this.TriggerAction.Bind(this), -delay)
        OutputDebug "计时器已启动，将在" this.seconds "秒后触发动作。"
    }

    TriggerAction() {
        this.targetObject.%this.targetMethod%()
    }

    ; PrintCount() {
    ;     while (1) {
    ;         OutputDebug this.Count++
    ;         Sleep 1000
    ;     }
    ; }
}

class Task {
    __New(taskName) {
        this.taskName := taskName
    }

    CompleteTask() {
        OutputDebug "任务完成：" this.taskName
    }

    Greey() {
        OutputDebug "Hello, " this.taskName
    }

}

; 测试脚本
seconds := 10 ; 设置计时时间（秒）
task_1 := Task("测试任务")  ; 创建任务对象
Alarm_1 := Timer(seconds, task_1, "CompleteTask")  ; 创建计时器对象并启动

; Sleep seconds * 2000
; task_2 := Task("task 2")  ; 创建任务对象
; timer_2 := Timer(seconds, task_2, "Greey")  ; 创建计时器对象并启动
