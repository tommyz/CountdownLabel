//
//  CountdownLabel.swift
//  CountdownLabel
//
//  Created by suzuki keishi on 2016/01/06.
//  Copyright © 2016 suzuki_keishi. All rights reserved.
//

import UIKit

extension TimeInterval {
    var int: Int {
        return Int(self)
    }
}

@objc public protocol CountdownLabelDelegate: AnyObject {
//    @objc optional func countdownStarted()
//    @objc optional func countdownPaused()
//    @objc optional func countdownFinished()
//    @objc optional func countdownCancelled()
//    @objc optional func countingAt(timeCounted: TimeInterval, timeRemaining: TimeInterval)
    
    @objc optional func countdownStarted(_ countdownLabel: CountdownLabel)
    @objc optional func countdownPaused(_ countdownLabel: CountdownLabel)
    @objc optional func countdownFinished(_ countdownLabel: CountdownLabel)
    @objc optional func countdownCancelled(_ countdownLabel: CountdownLabel)
    @objc optional func countingAt(_ countdownLabel: CountdownLabel, timeCounted: TimeInterval, timeRemaining: TimeInterval)

}

@objcMembers public class CountdownLabel: LTMorphingLabel {
    
    public typealias CountdownCompletion = () -> ()?
    public typealias CountdownExecution = () -> ()
    internal let defaultFireInterval = 1.0
    internal let date1970 = NSDate(timeIntervalSince1970: 0)
    
    // conputed property
    public var dateFormatter: DateFormatter {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(identifier: "GMT")
        df.dateFormat = timeFormat
        return df
    }
    
    public var timeCounted: TimeInterval {
        let timeCounted = NSDate().timeIntervalSince(fromDate as Date)
        return round(timeCounted < 0 ? 0 : timeCounted)
    }
    
    public var timeRemaining: TimeInterval {
        return round(currentTime) - timeCounted
    }
    
    public var isPaused: Bool {
        return paused
    }
    
    public var isCounting: Bool {
        return counting
    }
    
    public var isFinished: Bool {
        return finished
    }
    
    public weak var countdownDelegate: CountdownLabelDelegate?
    
    // user settings
    public var animationType: CountdownEffect? {
        didSet {
            if let effect = animationType?.toLTMorphing() {
                morphingEffect = effect
                morphingEnabled = true
            } else {
                morphingEnabled = false
            }
        }
    }
    public var timeFormat = "dd:hh:mm:ss"
    public var thens = [TimeInterval: CountdownExecution]()
    public var countdownAttributedText: CountdownAttributedText! {
        didSet {
            range = (countdownAttributedText.text as NSString).range(of: countdownAttributedText.replacement)
        }
    }
    
    internal var completion: CountdownCompletion?
    internal var fromDate: NSDate = NSDate()
    internal var currentDate: NSDate = NSDate()
    internal var currentTime: TimeInterval = 0
    internal var diffDate: NSDate!
    internal var targetTime: TimeInterval = 0
    internal var pausedDate: NSDate!
    internal var range: NSRange!
    internal var timer: Timer!
    
    internal var counting: Bool = false
    internal var endOfTimer: Bool {
        return timeCounted >= currentTime
    }
    internal var finished: Bool = false {
        didSet {
            if finished {
                paused = false
                counting = false
            }
        }
    }
    internal var paused: Bool = false
    
    // MARK: - Initialize
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    public override required init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    public convenience init(frame: CGRect, minutes: TimeInterval) {
        self.init(frame: frame)
        setCountDownTime(minutes: minutes)
    }
    
    public convenience init(frame: CGRect, date: NSDate) {
        self.init(frame: frame)
        setCountDownDate(targetDate: date)
    }
    
    public convenience init(frame: CGRect, fromDate: NSDate, targetDate: NSDate) {
        self.init(frame: frame)
        setCountDownDate(fromDate: fromDate, targetDate: targetDate)
    }
    
    deinit {
        dispose()
    }
    
    // MARK: - Setter Methods
    public func setCountDownTime(minutes: TimeInterval) {
        setCountDownTime(fromDate: NSDate(), minutes: minutes)
    }
    
    public func setCountDownTime(fromDate: NSDate, minutes: TimeInterval) {
        self.fromDate = fromDate
        
        targetTime = minutes
        currentTime = minutes
        diffDate = date1970.addingTimeInterval(minutes)
        
        updateLabel()
    }
    
    public func setCountDownDate(targetDate: NSDate) {
        setCountDownDate(fromDate: NSDate(), targetDate: targetDate)
    }
    
    public func setCountDownDate(fromDate: NSDate, targetDate: NSDate) {
        self.fromDate = fromDate
        
        targetTime = targetDate.timeIntervalSince(fromDate as Date)
        currentTime = targetDate.timeIntervalSince(fromDate as Date) 
        diffDate = date1970.addingTimeInterval(targetTime)
        
        updateLabel()
    }
    
    // MARK: - Update
    @objc func updateLabel() {
        // delegate
        countdownDelegate?.countingAt?(self, timeCounted: timeCounted, timeRemaining: timeRemaining)
        
        // then function execute if needed
        thens.forEach { k, v in
            if k.int == timeRemaining.int {
                v()
                thens[k] = nil
            }
        }
        
        // update text
        updateText()
        
        // if end of timer
        if endOfTimer {
            countdownDelegate?.countdownFinished?(self)
            dispose()
            completion?()
        }
    }
}

// MARK: - Public
extension CountdownLabel {
    public func start(completion: ( () -> () )? = nil) {
        if !isPaused {
            // current date should be setted at the time of the counter's starting, or the time will be wrong (just a few seconds) after the first time of pausing.
            currentDate = NSDate()
        }
        
        // pause status check
        updatePauseStatusIfNeeded()
        
        // create timer
        updateTimer()
        
        // fire!
        timer.fire()
        
        // set completion if needed
        completion?()
        
        // set delegate
        countdownDelegate?.countdownStarted?(self)
    }
    
    public func pause(completion: (() -> ())? = nil) {
        if paused {
            return
        }
        
        // invalidate timer
        disposeTimer()
        
        // stop counting
        counting = false
        paused = true
        
        // reset
        pausedDate = NSDate()
        
        // set completion if needed
        completion?()
        
        // set delegate
        countdownDelegate?.countdownPaused?(self)
    }
    
    public func cancel(completion: (() -> ())? = nil) {
//        text = dateFormatter.string(from: date1970.addingTimeInterval(0) as Date)
        dispose()
        
        // set completion if needed
        completion?()
        
        // set delegate
        countdownDelegate?.countdownCancelled?(self)
    }
    
    public func addTime(time: TimeInterval) {
        currentTime = time + currentTime
        diffDate = date1970.addingTimeInterval(currentTime)
        
        updateLabel()
    }
    
    @discardableResult
    public func then(targetTime: TimeInterval, completion: @escaping () -> ()) -> Self {
        let t = targetTime - (targetTime - targetTime)
        guard t > 0 else {
            return self
        }
        
        thens[t] = completion
        return self
    }
}

// MARK: - private
extension CountdownLabel {
    func setup() {
        morphingEnabled = false
    }
    
    func updateText() {
        guard diffDate != nil else { return }
        
        let date = diffDate.addingTimeInterval(round(timeCounted * -1)) as Date
        /*
        // if time is before start
        let formattedText = timeCounted < 0
            ? dateFormatter.string(from: date1970.addingTimeInterval(0) as Date)
            : self.surplusTime(date)
        */
        if timeCounted < 0 {
            return
        }
        let formattedText = self.surplusTime(date)
        
        if let countdownAttributedText = countdownAttributedText {
            let attrTextInRange = NSAttributedString(string: formattedText, attributes: countdownAttributedText.attributes)
            let attributedString = NSMutableAttributedString(string: countdownAttributedText.text)
            attributedString.replaceCharacters(in: range, with: attrTextInRange)
            
            attributedText = attributedString
            text = attributedString.string
        } else {
            text = formattedText
        }
        setNeedsDisplay()
    }
    
    //fix one day bug
    func surplusTime(_ to1970Date: Date) -> String {
        let calendar = Calendar.init(identifier: .gregorian)
        
        var act_tags: Array = Array<String>()
        
//        var labelText = dateFormatter.string(from: to1970Date)
        var labelText = ""
        let comp = calendar.dateComponents([.day, .hour, .minute, .second], from: date1970 as Date, to: to1970Date)
        
        // if day0 hour0 (24m10s) yes, day0 hour1 (12h10m) yes,d0 h1 m0 (10h0s) yes, day1 hour0 (2d10m)yes, day1 hour1 (1d1h)
//        if let day = comp.day ,let _ = timeFormat.range(of: "dd"),let hour = comp.hour ,let _ = timeFormat.range(of: "hh"),let minute = comp.minute ,let _ = timeFormat.range(of: "mm"),let second = comp.second ,let _ = timeFormat.range(of: "ss") {
        if let day = comp.day ,let hour = comp.hour ,let minute = comp.minute ,let second = comp.second {
            
            if (timeFormat.range(of: "dd") != nil) {
                act_tags.append(String.init(format: "%02ld", day))
            }
            
            if (timeFormat.range(of: "hh") != nil) {
                act_tags.append(String.init(format: "%02ld", hour))
            }
            
            if (timeFormat.range(of: "mm") != nil) {
                act_tags.append(String.init(format: "%02ld", minute))
            }
            
            if (timeFormat.range(of: "ss") != nil) {
                act_tags.append(String.init(format: "%02ld", second))
            }
            
        }
        labelText = act_tags.joined(separator: ":")
//        print("labelText\(labelText)")
        return labelText
    }
    
    func updatePauseStatusIfNeeded() {
        guard paused else {
            return
        }
        // change date
        let pastedTime = pausedDate.timeIntervalSince(currentDate as Date)
        currentDate = NSDate().addingTimeInterval(-pastedTime)
        fromDate = currentDate
        
        // reset pause
        pausedDate = nil
        paused = false
    }
    
    func updateTimer() {
        disposeTimer()
        
        // create
        timer = Timer.scheduledTimer(timeInterval: defaultFireInterval,
                                                       target: self,
                                                       selector: #selector(updateLabel),
                                                       userInfo: nil,
                                                       repeats: true)
        
        // register to NSrunloop
        RunLoop.current.add(timer, forMode: RunLoop.Mode.common)
        counting = true
    }
    
    func disposeTimer() {
        if timer != nil {
            timer.invalidate()
            timer = nil
        }
    }
    
    func dispose() {
        // reset
        pausedDate = nil
        
        // invalidate timer
        disposeTimer()
        
        // stop counting
        finished = true
    }
}

public enum CountdownEffect {
    case Anvil
    case Burn
    case Evaporate
    case Fall
    case None
    case Pixelate
    case Scale
    case Sparkle
    
    func toLTMorphing() -> LTMorphingEffect? {
        switch self {
        case .Anvil     : return .anvil
        case .Burn      : return .burn
        case .Evaporate : return .evaporate
        case .Fall      : return .fall
        case .None      : return nil
        case .Pixelate  : return .pixelate
        case .Scale     : return .scale
        case .Sparkle   : return .sparkle
        }
    }
}

public class CountdownAttributedText: NSObject {
    internal let text: String
    internal let replacement: String
    internal let attributes: [NSAttributedString.Key: Any]?

    public init(text: String, replacement: String, attributes: [NSAttributedString.Key: Any]? = nil) {
        self.text = text
        self.replacement = replacement
        self.attributes = attributes
    }
}
