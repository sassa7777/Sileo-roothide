//
//  DepictionTableTextButtonView.swift
//  Sileo
//
//  Created by CoolStar on 7/6/19.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import Foundation
import Evander

class DepictionTableTextButtonView: DepictionBaseView, UIGestureRecognizerDelegate {
    private var selectionView: UIView
    private var titleLabel: UILabel
    private var textLabel: UILabel
    private var chevronView: UIImageView
    private var repoIcon: UIImageView?

    private var action: String
    private var context: Any?

    required init?(dictionary: [String: Any], viewController: UIViewController, tintColor: UIColor, isActionable: Bool) {
        guard let title = dictionary["title"] as? String else {
            return nil
        }
        guard let text = dictionary["text"] as? String else {
            return nil
        }
        guard let action = dictionary["action"] as? String else {
            return nil
        }
        
        context = dictionary["context"]

        selectionView = UIView(frame: .zero)
        titleLabel = UILabel(frame: .zero)
        textLabel = UILabel(frame: .zero)
        chevronView = UIImageView(image: UIImage(named: "Chevron")?.withRenderingMode(.alwaysTemplate))

        self.action = action

        super.init(dictionary: dictionary, viewController: viewController, tintColor: tintColor, isActionable: isActionable)
        
        titleLabel.text = title
        titleLabel.textAlignment = .left
        titleLabel.font = UIFont.systemFont(ofSize: 17)
        titleLabel.lineBreakMode = .byTruncatingMiddle
        self.addSubview(titleLabel)
        
        textLabel.text = text
        textLabel.textAlignment = .right
        textLabel.font = UIFont.systemFont(ofSize: 17)
        textLabel.lineBreakMode = .byTruncatingMiddle
        textLabel.textColor = UIColor(white: 175.0/255.0, alpha: 1)
        self.addSubview(textLabel)

        self.addSubview(chevronView)
        
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(DepictionTableTextButtonView.buttonTapped))
        tapGestureRecognizer.delegate = self
        self.addGestureRecognizer(tapGestureRecognizer)

        self.accessibilityTraits = .link
        self.isAccessibilityElement = true
        self.accessibilityLabel = titleLabel.text
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func depictionHeight(width: CGFloat) -> CGFloat {
        44
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        titleLabel.textColor = self.tintColor
        chevronView.tintColor = self.tintColor

        var containerFrame = self.bounds
        containerFrame.origin.x = 16
        containerFrame.size.width -= 32

        selectionView.frame = self.bounds
        
        titleLabel.frame = CGRect(x: containerFrame.minX, y: 12, width: containerFrame.width - 20 - 10, height: 20.0)
        
        textLabel.frame = CGRect(x: containerFrame.minX + 10, y: 12, width: containerFrame.width - 20 - 10, height: 20)
        
        chevronView.frame = CGRect(x: containerFrame.maxX - 9, y: 15, width: 7, height: 13)
    }

    override func accessibilityActivate() -> Bool {
        self.buttonTapped(nil)
        return true
    }

    @objc func buttonTapped(_ gestureRecognizer: UIGestureRecognizer?) {
        if let gestureRecognizer = gestureRecognizer {
            if gestureRecognizer.state == .began {
                selectionView.alpha = 1
            } else if gestureRecognizer.state == .ended || gestureRecognizer.state == .cancelled || gestureRecognizer.state == .failed {
                selectionView.alpha = 0
            }

            if gestureRecognizer.state != .ended {
                return
            }
        }

        self.processAction(action)
    }

    @discardableResult func processAction(_ action: String) -> Bool {
        if action.isEmpty {
            return false
        }
        return DepictionButton.processAction(action, parentViewController: self.parentViewController, openExternal: false, context: context)
    }
}
