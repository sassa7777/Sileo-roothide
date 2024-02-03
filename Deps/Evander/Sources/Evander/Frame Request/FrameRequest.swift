//
//  FrameRequest.swift
//  
//
//  Created by Amy While on 30/12/2021.
//

import UIKit

#if swift(>=5.5)
@available(iOS 15, *)
public final class FrameRateRequest {
    
    static private var remainingTime: TimeInterval = 0
    static private var activeLink: CADisplayLink?
    static private var shared = FrameRateRequest()
    
    public class func perform(with duration: TimeInterval) {
        if !Thread.isMainThread {
            fatalError("Animations Cannot be Performed from a background thread")
        }
        if activeLink == nil {
            activeLink = makeLink()
            activeLink!.add(to: .main, forMode: .common)
        }
        remainingTime += duration
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            remainingTime -= duration
            if remainingTime == 0 {
                activeLink?.invalidate()
                activeLink = nil
            }
        }
    }
    
    private class func makeLink() -> CADisplayLink {
        let max = Float(UIScreen.main.maximumFramesPerSecond)
        var preferredFrameRate: Float = 120
        if preferredFrameRate > max {
            preferredFrameRate = max
        }
        let frameRateRange = CAFrameRateRange(minimum: 30, maximum: max, preferred: preferredFrameRate)
        let displayLink = CADisplayLink(target: FrameRateRequest.shared, selector: #selector(dummyFunction))
        displayLink.preferredFrameRateRange = frameRateRange
        return displayLink
    }
        
    @objc private func dummyFunction() {}
}
#endif

@objc public final class FRUIView: NSObject {
    
    @objc class public func animate(withDuration duration: TimeInterval,
                       delay: TimeInterval,
                       options: UIView.AnimationOptions = [],
                       animations: @escaping () -> Void,
                       completion: ((Bool) -> Void)? = nil) {
        #if swift(>=5.5)
        if #available(iOS 15, *) {
            FrameRateRequest.perform(with: duration)
        }
        #endif
        UIView.animate(withDuration: duration, delay: delay, options: options, animations: animations, completion: completion)
    }
    
    @objc class public func animate(withDuration duration: TimeInterval,
                              animations: @escaping () -> Void,
                              completion: ((Bool) -> Void)? = nil) {
        #if swift(>=5.5)
        if #available(iOS 15, *) {
            FrameRateRequest.perform(with: duration)
        }
        #endif
        UIView.animate(withDuration: duration, animations: animations, completion: completion)
    }
    
    @objc class public func animate(withDuration duration: TimeInterval,
                              animations: @escaping () -> Void) {
        #if swift(>=5.5)
        if #available(iOS 15, *) {
            FrameRateRequest.perform(with: duration)
        }
        #endif
        UIView.animate(withDuration: duration, animations: animations)
    }
    
    
    @objc class public func animateKeyframes(withDuration duration: TimeInterval,
                                       delay: TimeInterval,
                                       options: UIView.KeyframeAnimationOptions = [],
                                       animations: @escaping () -> Void,
                                       completion: ((Bool) -> Void)? = nil) {
        #if swift(>=5.5)
        if #available(iOS 15, *) {
            FrameRateRequest.perform(with: duration)
        }
        #endif
        UIView.animateKeyframes(withDuration: duration, delay: delay, options: options, animations: animations, completion: completion)
    }
     
    
    @objc class public func animate(withDuration duration: TimeInterval,
                               delay: TimeInterval,
                               usingSpringWithDamping dampingRatio: CGFloat,
                               initialSpringVelocity velocity: CGFloat,
                               options: UIView.AnimationOptions = [],
                               animations: @escaping () -> Void,
                               completion: ((Bool) -> Void)? = nil) {
        #if swift(>=5.5)
        if #available(iOS 15, *) {
            FrameRateRequest.perform(with: duration)
        }
        #endif
        UIView.animate(withDuration: duration, delay: delay, usingSpringWithDamping: dampingRatio, initialSpringVelocity: velocity, options: options, animations: animations, completion: completion)
     }
    
}
