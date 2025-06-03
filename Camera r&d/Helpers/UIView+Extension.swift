//
//  UIView+Extension.swift
//  Camera r&d
//
//  Created by Appnap WS05 on 6/2/25.
//

import UIKit

extension UIView{
    func fillSuperview(){
        guard let superview else{return}
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate(
            [topAnchor.constraint(equalTo: superview.topAnchor),
             leftAnchor.constraint(equalTo: superview.leftAnchor),
             bottomAnchor.constraint(equalTo: superview.bottomAnchor),
             rightAnchor.constraint(equalTo: superview.rightAnchor),
            ]
        )
    }
    
    func anchorView(top: NSLayoutYAxisAnchor? = nil,
                    left: NSLayoutXAxisAnchor? = nil,
                    bottom: NSLayoutYAxisAnchor? = nil,
                    right: NSLayoutXAxisAnchor? = nil,
                    paddingTop: CGFloat = 0,
                    paddingLeft: CGFloat = 0,
                    paddingBottom: CGFloat = 0,
                    paddingRight: CGFloat = 0
    ){
        translatesAutoresizingMaskIntoConstraints = false
        
        if let top{
            self.topAnchor.constraint(equalTo: top, constant: paddingTop).isActive = true
        }
        if let left{
            self.leftAnchor.constraint(equalTo: left, constant: paddingLeft).isActive = true
        }
        if let bottom{
            self.bottomAnchor.constraint(equalTo: bottom, constant: -paddingBottom).isActive = true
        }
        if let right{
            self.rightAnchor.constraint(equalTo: right, constant: -paddingRight).isActive = true
        }
    }
    
    func center(in view: UIView){
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate(
            [
                centerXAnchor.constraint(equalTo: view.centerXAnchor),
                centerYAnchor.constraint(equalTo: view.centerYAnchor),
            ]
        )
    }
    
    func centerAnchor(x: UIView? = nil, y: UIView? = nil){
        
        translatesAutoresizingMaskIntoConstraints = false

        if let x{
            self.centerXAnchor.constraint(equalTo: x.centerXAnchor).isActive = true
        }
        if let y{
            self.centerYAnchor.constraint(equalTo: y.centerYAnchor).isActive = true
        }
    }
    
    func setDimesion(width: CGFloat? = nil, height: CGFloat? = nil){
        translatesAutoresizingMaskIntoConstraints = false
        
        if let width{
            self.widthAnchor.constraint(equalToConstant: width).isActive = true
        }
        if let height{
            self.heightAnchor.constraint(equalToConstant: height).isActive = true
        }
    }
}
