//
//  WaterflowView.swift
//  AZB
//
//  Created by Ama on 11/1/16.
//  Copyright © 2016 Ama. All rights reserved.
//  https://www.jianshu.com/p/9b019c83d758

import UIKit
//这里的WaterflowMarginType是相应的间隔类型的枚举类，为什么会使用@objc？因为此枚举在代理方法中被用作参数传递了，所有需要在枚举开头加上@objc
@objc public enum WaterflowMarginType: Int {
    case top
    case bottom
    case left
    case right
    case column
    case row
}
//数据源方法和代理方法也加上了@objc，目的在于设置协议的 optional 属性。
@objc public protocol WaterflowDataSource: NSObjectProtocol {
    
    func numberOfCellsInWaterflow(waterflow: WaterflowView) -> Int
    
    func waterflow(waterflow: WaterflowView, cellAtIndex index: Int) -> WaterflowViewCell
//数据源中的第三个方法numberOfColumnsInWaterflow要求返回所要展示的 cell 的列数，当然不实现此方法的话默认会展示三列。
    @objc optional func numberOfColumnsInWaterflow(waterflow: WaterflowView) -> Int
}
//数据源方法和代理方法也加上了@objc，目的在于设置协议的 optional 属性。
@objc public protocol WaterflowDelegate: NSObjectProtocol {
    //heightAtIndex方法要求返回 cell 的高度，默认是44；
    @objc optional func waterflow(waterflow: WaterflowView, heightAtIndex index: Int) -> CGFloat
    //didSelectAtIndex方法是 cell 的点击回调；
    @objc optional func waterflow(waterflow: WaterflowView, didSelectAtIndex index: Int)
    //marginForType方法返回 cell 间间隙的宽度，默认是1。
    @objc optional func waterflow(waterflow: WaterflowView, marginForType type: WaterflowMarginType) -> CGFloat
}

public class WaterflowView: UIScrollView {

    // delegate
    public var dataSource: WaterflowDataSource?
    public var wfDelegate: WaterflowDelegate?
    
    //用于存放所有 cell 的 frame
    fileprivate lazy var cellFrames = NSMutableArray()
    //用于存放正在显示的 cell, 字典的 key 为 index，value 为 cell 对象；
    fileprivate lazy var displayingCells = NSMutableDictionary()
    //用于存放所有离开屏幕的 cell,因为不需要公开，所有设置为私有
    fileprivate lazy var reusableCells = NSMutableSet()
    
    //  默认值
    fileprivate let WaterflowDefaultCellH: CGFloat = 44
    fileprivate let WaterflowDefaultMargin: CGFloat = 1
    fileprivate let WaterflowDefaultNumberOfColumns: Int = 3
    
    // 遮罩层，用于当用户点击cell 之后，展示点击效果
    fileprivate lazy var matteView: UIView = {
        var view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.1)
        return view
    }()
    
    // 用于记录 cell
    fileprivate var cTupe: (NSNumber?, WaterflowViewCell?)
//对于 cell 的穿件以及属性的计算将会在`willMoveToSuperview`和`layoutSubviews`中完成，`willMoveToSuperview`什么时候会被触发？
  override public func willMove(toSuperview newSuperview: UIView?) {
        reloadData()
    }
}

// MARK: - public method
extension WaterflowView {
    //cellWidth方法可以获取到 cell 的宽度
    func cellWidth() -> CGFloat {
        let columns = numberOfColumns()
        let leftM = marginForType(type: .left)
        let rightM = marginForType(type: .right)
        let columnM = marginForType(type: .column)
        
        return (bounds.width - leftM - rightM - (CGFloat(columns) - 1) * columnM) / CGFloat(columns)
    }
    
    public func reloadData() {
        /*!
         displayingCells为当前屏幕显示的 cell，是一个字典，
         因此通过 allValues 可获取到字典中所有的 cell 对象，
         forEach方法属于 for 循环的特殊用法（在forEach闭包中，
         $0表示 字典中的 value，当然也可用闭包通用形式中 {value in method} 来编写），
         这里需要移除所有的 cell。
         */
        displayingCells.allValues.forEach {
            ($0 as AnyObject).removeFromSuperview()
        }
        
        // 清空数组、字典、集合
        displayingCells.removeAllObjects()
        cellFrames.removeAllObjects()
        reusableCells.removeAllObjects()
        
        // 获取 cell 的总数
        let cells = dataSource?.numberOfCellsInWaterflow(waterflow: self)
        
        // waterflow 的列数
        let columns = numberOfColumns()
        
        // cell 间的间隙
        let topM = marginForType(type: .top)
        let bottomM = marginForType(type: .bottom)
        let leftM = marginForType(type: .left)
        let columnM = marginForType(type: .column)
        let rowM = marginForType(type: .row)
        
        let cellW = cellWidth()
        
        // 创建一个空的数组，数字里面的子元素为列的个数，用来记录列的Y值，用于创建作为列的下一个cell的Y轴起点
        var maxYOfColumns: Array<CGFloat> = Array(repeating: 0.0, count: columns)
        // 循环初始化所有列的最大 y 值，瀑布流中每一行的 cell 所在位置是上一行中 y 值最小的 cell
        /*个人理解：
         初始化列里面布局Y轴起点(例如有3列，3列的起始Y轴都是0)
         */
        for i in 0..<columns {
            maxYOfColumns[i] = 0.0
        }
        
        // cells == nil return  如果cell的个数为空就直接返回。
        guard let _cells = cells else {
            return
        }
        
        for i in 0..<_cells {
            // 找出 y 值最小的 cell
            var cellColumn = 0
            var maxYOfCellColumn = maxYOfColumns[cellColumn]
            for j in 1..<columns {
                if maxYOfColumns[j] < maxYOfCellColumn {
                    cellColumn = j
                    maxYOfCellColumn = maxYOfColumns[j]
                }
            }
            //获取cell的高度
            let cellH = heightAtIndex(index: i)
   //cell的X轴的起点  leftM(左边间隙) + cellColumn(当前列数) * ((cellW)cell的宽度+(columnM)中间的间隙)
            let cellX: CGFloat = leftM + CGFloat(cellColumn) * (cellW + columnM)
            //初始化cell的Y轴的起点
            var cellY: CGFloat = 0.0
            //如果maxYOfCellColumn等于0说明当前列是第一个开始布局，如果不是maxYOfCellColumn会存储一个列的最大Y值。
            if maxYOfCellColumn == 0.0 {
                //第一个列开始布局
                cellY = topM
            } else {
                //列后面的起点取决于之间记录的Y值+下一个cell相对上一个cell的间隙。
                cellY = maxYOfCellColumn + rowM
            }
            
            // 把 cell 的 frame 添加到 cellFrame 数组中，并记录当前列的最大 y 值
            /*
             把一个cell布局需要的信息拿到之后。存储到cellFrames的数组里面。X轴,Y轴,cell宽,cell高。
             */
            let cellFrame = CGRect(x: cellX, y: cellY, width: cellW, height: cellH)
            cellFrames.add(NSValue(cgRect: cellFrame))
            //记录最大的Y值数据作为下一个cell的起点
            maxYOfColumns[cellColumn] = cellFrame.maxY
        }
        
        //下面的整个步骤的目的就是计算scrollView的高度，比较列的最大的Y值
        var contentH = maxYOfColumns[0]
        for j in 0..<columns {
            if maxYOfColumns[j] > contentH {
                contentH = maxYOfColumns[j]
            }
        }
        //如果有底部间隙的话就加上底部间隙
        contentH += bottomM
        // 设置 scrollView 的 contentSize
        contentSize = CGSize(width: 0, height: contentH)
    }
    
    //layoutSubviews每次滚动屏幕时都会触发
  override public func layoutSubviews() {
        super.layoutSubviews()
        
        // 索要对应位置的 cell
        let cells = cellFrames.count
        for i in 0..<cells {
            // 取出 i index 中的 frame
            let cellFrame = (cellFrames[i] as AnyObject).cgRectValue
            // 优先从字典中取出 cell
            var cell: WaterflowViewCell? = displayingCells[i] as? WaterflowViewCell
            
            // 判断对应的 frame 在不在屏幕上
            if isInScreen(frame: cellFrame!) {
                
                // 如果 frame 在屏幕上，但是 cell 并没有被创建，
                // 则创建 cell，并且存放进 displayingCells字典中
                guard cell != nil else {
                    cell = dataSource?.waterflow(waterflow: self, cellAtIndex: i)
                    cell!.frame = cellFrame!
                    addSubview(cell!)
                    displayingCells[i] = cell
                    
                    continue
                }
                
                continue
                
            } else {
                
                // 如果不在，则把 cell 从当前屏幕中移除，并添加到缓存中
                guard let cell = cell else {
                    continue
                }
                
                cell.removeFromSuperview()
                displayingCells.removeObject(forKey: i)
                reusableCells.add(cell)
            }
        }
    }
    
    //重用cell的方法
    /*
     里面的主要写了，传进来的这个identifier看看缓存池里面有没有，有就拿出开用，并从缓存池移除。没有就创建。
     但我不知道为什么要移除。因为你从缓存池里面把你想要的类型的cell拿走可就咩有了，缓存池存储的cell的独一无二的
     只有一个拿走就没有了。
     */
    public func dequeueReusableCellWithIdentifier(identifier: String) -> AnyObject? {
        var reusableCell: WaterflowViewCell?
        for cell in reusableCells {
            let cell = cell as! WaterflowViewCell
            if cell.identifier == identifier {
                reusableCell = cell
                break
            }
        }
        
        if reusableCell != nil {
            reusableCells.remove(reusableCell!)
        }
        return reusableCell
    }
}

// MARK: - private
extension WaterflowView {
    // 判断传进来的 frame 在不在屏幕上
    fileprivate func isInScreen(frame: CGRect) -> Bool {
        return (frame.maxY > contentOffset.y) &&
            (frame.maxY < contentOffset.y + bounds.height)
    }
    //cell之间的间距
    fileprivate func marginForType(type: WaterflowMarginType) -> CGFloat {
        return wfDelegate?.waterflow?(waterflow: self, marginForType: type) ?? WaterflowDefaultMargin
    }
    //一行显示的个数
    fileprivate func numberOfColumns() -> Int {
        return dataSource?.numberOfColumnsInWaterflow?(waterflow: self) ?? WaterflowDefaultNumberOfColumns
    }
    //cell的高度
    fileprivate func heightAtIndex(index: Int) -> CGFloat {
        return wfDelegate?.waterflow?(waterflow: self, heightAtIndex: index) ?? WaterflowDefaultCellH
    }
}

// MARK: - action - 点击的时候执行
extension WaterflowView {
    
  override public func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard wfDelegate != nil else {
            return
        }
        
        let cellTupe = getCurrentTouchView(touches: touches)
        let cell = cellTupe.1
        
        guard let _cell = cell else {
            return
        }
        
        cTupe = cellTupe
        
        // 添加遮罩
        matteView.frame = _cell.bounds
        _cell.addSubview(matteView)
        _cell.bringSubview(toFront: matteView)
    }
    
  override public func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let wfDelegate = wfDelegate else {
            return
        }
        
        let cellTupe = getCurrentTouchView(touches: touches)
        let selectIdx = cellTupe.0
        
        if selectIdx == cTupe.0 {
            
            let cell = cellTupe.1
            
            // 移除遮罩
            let matteV = cell?.subviews.last
            matteV?.removeFromSuperview()
            
            if (selectIdx != nil) {
                wfDelegate.waterflow?(waterflow: self, didSelectAtIndex: selectIdx!.intValue)
            }
        }
    }
    
  override public func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        let cellTupe = getCurrentTouchView(touches: touches)
        // 如果不在点击层 移除遮罩
        if cTupe.0 != cellTupe.0 {
            let matteV = cTupe.1!.subviews.last
            matteV?.removeFromSuperview()
        } else {
            // 如果在点击层且没有遮罩，添加遮罩
            if cellTupe.1!.subviews.last != matteView {
                matteView.frame = cellTupe.1!.bounds
                cellTupe.1!.addSubview(matteView)
                cellTupe.1!.bringSubview(toFront: matteView)
            }
        }
    }
    
    private func getCurrentTouchView(touches: Set<UITouch>) -> (NSNumber?, WaterflowViewCell?) {
        let touch: UITouch = (touches as NSSet).anyObject() as! UITouch
        let point = touch.location(in: self)
        
        var selectIdx: NSNumber?
        var selectCell: WaterflowViewCell?
        
        // 获取点击层对应的 cell
        for (key, value) in displayingCells {
            let cell = value as! WaterflowViewCell
            if cell.frame.contains(point) {
                selectIdx = (key as! NSNumber)
                selectCell = cell
                break
            }
        }
        return (selectIdx, selectCell)
    }
    
}

