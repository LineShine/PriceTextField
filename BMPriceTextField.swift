//
//  BMPriceTextField.swift
//  BMUI
//
//  Created by Linc on 2021/3/3.
//

import UIKit

@objc
public protocol BMPriceProtocol: UITextFieldDelegate {
    /// 内容发生变化
    @objc
    optional func textFieldDidChange(_ textField: UITextField)
    /// 小数位超过限制
    @objc
    optional func textFieldDecimalPlaceOverflow(_ textField: UITextField)
    /// 最大值超过限制
    @objc
    optional func textFieldMaxValueOverflow(_ textField: UITextField)
    /// 最小值超过限制
    @objc
    optional func textFieldMinValueOverflow(_ textField: UITextField)
}

public class BMPriceTextField: UITextField {

    /// 只能输入数字+.
    private let kDecimalOnly = ".0123456789"
    /// 只能输入纯数字
    private let kNumberOnly = "0123456789"
    
    /// 是否支持小数位
    /// 默认：true 支持
    public var isDecimal: Bool = true
    
    /// 小数点后位数
    /// 默认：nil-不验证
    public var decimalPlace: UInt? = nil
    
    /// 设置最大值
    /// 默认：nil-不限制
    public var max: CGFloat? = nil
    
    /// 设置最小值
    /// 默认：nil-不限制
    public var min: CGFloat? = nil
    
    public override var delegate: UITextFieldDelegate? {
        didSet {
            super.delegate = self
        }
    }
    
    public override var keyboardType: UIKeyboardType {
        didSet {
            super.keyboardType = isDecimal ? .decimalPad : .numberPad
        }
    }
    
    public var priceDelegate: BMPriceProtocol?
    
    public init(frame: CGRect = CGRect.zero, isDecimal: Bool = true, decimalPlace: UInt? = nil) {
        super.init(frame: frame)
        
        self.isDecimal = isDecimal
        self.decimalPlace = decimalPlace
        
        DispatchQueue.main.async {
            self.setupUI()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        delegate = self
        keyboardType = isDecimal ? .decimalPad : .numberPad
        
        self.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        
        //禁用双击手势
        let tap2 = UITapGestureRecognizer(target: self, action: nil)
        tap2.numberOfTapsRequired = 2
        self.addGestureRecognizer(tap2)
    }
    
}

//MARK: - Delegate
extension BMPriceTextField: UITextFieldDelegate {
    
    public func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        var result = false
        
        //校验
        if let str = textField.text , str.count > 0 {
            let arr = str.split(separator: ".")
            if arr.count < 3 {
                result = true
            } else {
                //多个小数点
                result = false
            }
        } else {
            result = true
        }
        
        //4、最小值
        if let minValue = min, result == true {
            if let str = textField.text , str.count > 0 {
                let newValue = CGFloat(Double(str) ?? 0.0)
                if newValue < minValue {
                    priceDelegate?.textFieldMinValueOverflow?(textField)
                    result = false
                }
            }
        }
        
        if result == false {
            return false
        }
        return priceDelegate?.textFieldShouldEndEditing?(textField) ?? true
    }
    
    public func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        
        //1、基础Float验证
        if isDecimal == true { //带小数模式
            if let str = textField.text , str.count > 0 {
                if string == "." && (str.range(of: ".") != nil) { //避免两个.
                    return false
                }
                if str == "0" && string.count > 0 { //第一位为0，第二位必须是.
                    textField.text = "0."
                    return false
                }
            } else {
                if string == "." {        //第一位为. 直接显示为0.
                    textField.text = "0"
                } else if string == "0" { //第一位为0 直接显示为0.
                    textField.text = "0."
                    return false
                }
            }
        } else { //纯数字模式
            if string == "0" && (textField.text == nil || textField.text == "") {
                return false //第一位为0 不能输入
            }
        }
        
        //2、小数位位数
        if let place = decimalPlace {
            if let str = textField.text , str.count > 0, string.count > 0 {
                let arr = str.split(separator: ".")
                if arr.count == 2 {
                    let last = arr.last
                    if (last?.count ?? 0) + string.count > place {
                        priceDelegate?.textFieldDecimalPlaceOverflow?(textField)
                        return false
                    }
                }
            }
        }
        
        //3、最大值
        if let maxValue = max {
            if string.count > 0 {
                let newStr = "\(textField.text ?? "0")\(string)"
                let newValue = CGFloat(Double(newStr) ?? 0.0)
                if newValue > maxValue {
                    priceDelegate?.textFieldMaxValueOverflow?(textField)
                    return false
                }
            }
        }
        
        return priceDelegate?.textField?(textField, shouldChangeCharactersIn: range, replacementString: string) ?? true
    }
    
    /// 仅处理联想输入的情况
    /// 联想输入不会触发 shouldChangeCharactersIn:replacementString:
    @objc
    private func textFieldDidChange() {
        print(self.text ?? "")
        if let str = self.text, str.count > 0 {
            if Double(str) != nil {
                
                priceDelegate?.textFieldDidChange?(self)
                return
            }
            //仅取出数字(+.)
            let arr = isDecimal ? kDecimalOnly : kNumberOnly
            var newStr: String = ""
            for i in 0 ..< str.count {
                let char = str[str.index(str.startIndex, offsetBy: i)]
                if arr.contains(char) == true {
                    newStr.append(char)
                }
            }
            self.text = newStr
        } else {
            priceDelegate?.textFieldDidChange?(self)
        }
    }
    
    /// 禁用textField的长按菜单 禁止copy paste
    public override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        UIMenuController.shared.isMenuVisible = false
        return false
    }
    
    /// 禁止长按时光标移动
    public override var selectedTextRange: UITextRange? {
        didSet {
            guard let start = self.position(from: self.beginningOfDocument, offset: self.text?.count ?? 0) else { return }
            guard let end = self.position(from: start, offset: 0) else { return }
            super.selectedTextRange = self.textRange(from: start, to: end)
        }
    }
    
    //MARK: - others
    public func textFieldDidBeginEditing(_ textField: UITextField) {
        priceDelegate?.textFieldDidBeginEditing?(textField)
    }
    
    public func textFieldDidEndEditing(_ textField: UITextField) {
        priceDelegate?.textFieldDidEndEditing?(textField)
    }
    
    public func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        return priceDelegate?.textFieldShouldBeginEditing?(textField) ?? true
    }
    
    @available(iOS 10.0, *)
    public func textFieldDidEndEditing(_ textField: UITextField, reason: UITextField.DidEndEditingReason) {
        if priceDelegate?.responds(to: #selector(textFieldDidEndEditing(_:reason:))) == true {
            priceDelegate?.textFieldDidEndEditing?(textField, reason: reason)
        } else {
            priceDelegate?.textFieldDidEndEditing?(textField)
        }
    }
    
    @available(iOS 13.0, *)
    public func textFieldDidChangeSelection(_ textField: UITextField) {
        priceDelegate?.textFieldDidChangeSelection?(textField)
    }
    
    public func textFieldShouldClear(_ textField: UITextField) -> Bool {
        return priceDelegate?.textFieldShouldClear?(textField) ?? true
    }

    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        return priceDelegate?.textFieldShouldReturn?(textField) ?? true
    }
    
}
