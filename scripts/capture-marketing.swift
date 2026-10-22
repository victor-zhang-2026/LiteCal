import AppKit
@main struct MarketingCapture {
    static func main() throws {
        let app = NSApplication.shared; app.setActivationPolicy(.accessory)
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let output = root.appendingPathComponent("marketing/v1.1.0/source-assets")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let data = root.appendingPathComponent("qa/marketing-capture-" + UUID().uuidString)
        let store = EventStore(directory: data)
        let items = [("产品方案评审","2026-10-01","2026-10-01"), ("杭州出差","2026-10-02","2026-10-04"), ("需求整理","2026-10-06","2026-10-06"), ("团队会议","2026-10-07","2026-10-07"), ("客户沟通","2026-10-10","2026-10-10"), ("出差南京","2026-10-12","2026-10-13"), ("季度规划","2026-10-14","2026-10-14"), ("朋友生日","2026-10-18","2026-10-18"), ("项目复盘","2026-10-20","2026-10-20"), ("设计同步","2026-10-21","2026-10-21"), ("团队会议","2026-10-22","2026-10-22"), ("客户方案","2026-10-22","2026-10-22"), ("读书分享","2026-10-22","2026-10-22"), ("杭州交流","2026-10-23","2026-10-25"), ("版本发布","2026-10-26","2026-10-26"), ("月度总结","2026-10-30","2026-10-30"), ("上线准备","2026-10-30","2026-11-02")]
        for (title, start, end) in items { try store.save(title: title, startDate: CivilDate(key:start)!, endDate:CivilDate(key:end)!) }
        let controller = FloatingController(store: store, defaults: UserDefaults(suiteName:"app.litecal.marketing")!)
        controller.calendar.todayProvider = { CivilDate(key:"2026-10-22")! }
        controller.open(); controller.pinCalendar()
        controller.calendar.jump(to: CivilDate(key:"2026-10-01")!)
        controller.panel.setContentSize(NSSize(width:980,height:760)); controller.calendar.layoutSubtreeIfNeeded()
        func snapshot(_ view:NSView, _ name:String, rect:NSRect? = nil) throws {
            view.layoutSubtreeIfNeeded(); view.displayIfNeeded()
            let bounds=rect ?? view.bounds
            let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:Int(bounds.width*2),pixelsHigh:Int(bounds.height*2),bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
            bitmap.size=bounds.size; view.cacheDisplay(in:bounds,to:bitmap)
            try bitmap.representation(using:.png,properties:[:])!.write(to:output.appendingPathComponent(name+".png"))
        }
        try snapshot(controller.calendar,"calendar")
        try snapshot(controller.calendar,"week",rect:NSRect(x:0,y:496,width:980,height:132))
        try snapshot(controller.calendar,"today",rect:NSRect(x:420,y:496,width:140,height:132))
        try snapshot(controller.trigger.contentView!,"trigger")
        let event=store.events.first{$0.title=="杭州交流"}!
        controller.edit(event:event,day:event.startDate); let editor=controller.editor!
        editor.window.makeFirstResponder(nil)
        try snapshot(editor.window.contentView!,"editor")
        let grid=DateSelectionGrid(selected:event.startDate,minimum:nil)
        grid.beginRange(event.startDate)
        let last=grid.dayButtons.first{$0.day==event.endDate}!
        grid.updateRange(at:NSPoint(x:last.frame.midX,y:last.frame.midY))
        try snapshot(grid,"date-range")
        let picker=MonthJumpPicker(month:CivilDate(key:"2026-10-01")!)
        picker.buttons[10].mouseEntered(with:NSEvent.mouseEvent(with:.mouseMoved,location:.zero,modifierFlags:[],timestamp:0,windowNumber:0,context:nil,eventNumber:0,clickCount:0,pressure:0)!)
        try snapshot(picker.popover.contentViewController!.view,"month-picker")
        editor.finish(); controller.close(); controller.trigger.orderOut(nil)
        print("Native marketing captures saved. Fictional data isolated at \(data.lastPathComponent)")
    }
}
