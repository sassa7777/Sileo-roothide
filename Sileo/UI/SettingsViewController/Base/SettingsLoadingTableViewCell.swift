//
//  SettingsLoadingTableViewCell.swift
//  Sileo
//
//  Created by Skitty on 1/27/20.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import Foundation

class SettingsLoadingTableViewCell: UITableViewCell {
    private var loadingView = UIActivityIndicatorView(style: UIActivityIndicatorView.Style.gray)
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.selectionStyle = UITableViewCell.SelectionStyle.none
        self.accessoryType = UITableViewCell.AccessoryType.none
        loadingView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(loadingView)
        
        loadingView.centerXAnchor.constraint(greaterThanOrEqualTo: self.centerXAnchor).isActive = true
        loadingView.centerYAnchor.constraint(greaterThanOrEqualTo: self.centerYAnchor).isActive = true
    }
    
    func startAnimating() {
        loadingView.startAnimating()
    }

    func stopAnimating() {
        loadingView.stopAnimating()
    }
}
