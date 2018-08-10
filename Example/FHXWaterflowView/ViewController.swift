//
//  ViewController.swift
//  FHXWaterflowView
//
//  Created by fenghanxu on 08/10/2018.
//  Copyright (c) 2018 fenghanxu. All rights reserved.
//

import UIKit
import FHXWaterflowView

class ViewController: UIViewController {
  
  var waterFlowLayoutView = WaterflowView()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    buildUI()
  }
  
  func buildUI(){
    view.backgroundColor = UIColor.white
    buildSubview()
    buildLayout()
  }
  
  func buildSubview(){
    waterFlowLayoutView = WaterflowView(frame: view.bounds)
    waterFlowLayoutView.dataSource = self
    waterFlowLayoutView.wfDelegate = self
    //自动调节子控件的宽度跟父空间的宽度一样
    waterFlowLayoutView.autoresizingMask = .flexibleWidth
    view.addSubview(waterFlowLayoutView)
  }
  
  func buildLayout(){
    
  }
  
}

extension ViewController: WaterflowDelegate, WaterflowDataSource {
  
  //cell的总个数
  func numberOfCellsInWaterflow(waterflow: WaterflowView) -> Int {
    return 100
  }
  //cell赋值
  func waterflow(waterflow: WaterflowView, cellAtIndex index: Int) -> WaterflowViewCell {
    var cell = waterflow.dequeueReusableCellWithIdentifier(identifier: "wfCell") as? WaterflowViewCell
    if cell == nil {
      cell = WaterflowViewCell()
      cell?.identifier = "wfCell"
    }
    cell?.backgroundColor = randomColor()
    return cell!
  }
  
  //一行显示的个数
  func numberOfColumnsInWaterflow(waterflow: WaterflowView) -> Int {
    if UIInterfaceOrientationIsPortrait(preferredInterfaceOrientationForPresentation) {
      return 3
    } else {
      return 5
    }
  }
  
  // MARK: - wfdelegate
  func waterflow(waterflow: WaterflowView, didSelectAtIndex index: Int) {
    print(index)
  }
  
  //cell的高度
  func waterflow(waterflow: WaterflowView, heightAtIndex index: Int) -> CGFloat {
    return (index % 2 == 0) ? 100 : 50
  }
  
  //cell之间的间距
  func waterflow(waterflow: WaterflowView, marginForType type: WaterflowMarginType) -> CGFloat {
    return 10
  }
  
  override func didRotate(from fromInterfaceOrientation: UIInterfaceOrientation) {
    waterFlowLayoutView.reloadData()
  }
  
  //每个cell的颜色
  func randomColor() -> UIColor {
    let red: CGFloat  = CGFloat(arc4random_uniform(256))/255
    let green: CGFloat = CGFloat(arc4random_uniform(256))/255
    let blue: CGFloat  = CGFloat(arc4random_uniform(256))/255
    let alpha: CGFloat = 1.0
    return UIColor.init(red: red, green: green, blue: blue, alpha: alpha)
  }
  
}



