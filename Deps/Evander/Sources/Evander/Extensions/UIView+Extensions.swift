//  Created by Andromeda on 01/10/2021.
//

import UIKit

public extension UIView {
    
    class func fromNib<T: UIView>() -> T {
        Bundle(for: T.self).loadNibNamed(String(describing: T.self), owner: nil, options: nil)![0] as! T
    }
    
    var parentView: UIViewController? {
        var parentResponder: UIResponder? = self
        while parentResponder != nil {
            parentResponder = parentResponder?.next
            if let viewController = parentResponder as? UIViewController {
                return viewController
            }
        }
        return nil
    }

    func aspectRatio(_ ratio: CGFloat) -> NSLayoutConstraint {
        NSLayoutConstraint(item: self, attribute: .height, relatedBy: .equal, toItem: self, attribute: .width, multiplier: ratio, constant: 0)
    }
    
    func center(in superview: UIView) {
        NSLayoutConstraint.activate([
            centerXAnchor.constraint(equalTo: superview.centerXAnchor),
            centerYAnchor.constraint(equalTo: superview.centerYAnchor)
        ])
    }
    
    func constraintsPinningTo(view: UIView, top: CGFloat = 0, bottom: CGFloat = 0, leading: CGFloat = 0, trailing: CGFloat = 0) -> [NSLayoutConstraint] {
        return [
            topAnchor.constraint(equalTo: view.topAnchor, constant: top),
            leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: leading),
            trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: trailing),
            bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: bottom)
        ]
    }
    
    func constraintsPinningTo(guide: UILayoutGuide, top: CGFloat = 0, bottom: CGFloat = 0, leading: CGFloat = 0, trailing: CGFloat = 0) -> [NSLayoutConstraint] {
        return [
            topAnchor.constraint(equalTo: guide.topAnchor, constant: top),
            leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: leading),
            trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: trailing),
            bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: bottom)
        ]
    }
    
    func pinTo(view: UIView, top: CGFloat = 0, bottom: CGFloat = 0, leading: CGFloat = 0, trailing: CGFloat = 0) {
        NSLayoutConstraint.activate(constraintsPinningTo(view: view, top: top, bottom: bottom, leading: leading, trailing: trailing))
    }
    
    func pinTo(guide: UILayoutGuide, top: CGFloat = 0, bottom: CGFloat = 0, leading: CGFloat = 0, trailing: CGFloat = 0) {
        NSLayoutConstraint.activate(constraintsPinningTo(guide: guide, top: top, bottom: bottom, leading: leading, trailing: trailing))
    }

}
