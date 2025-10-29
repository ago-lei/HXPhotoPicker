//
//  PhotoPreviewListViewLayout.swift
//  HXPhotoPicker
//
//  Created by Silence on 2023/11/23.
//  Copyright © 2023 Silence. All rights reserved.
//

import UIKit

class PhotoPreviewListViewLayout: UICollectionViewLayout {
    enum Style {
        case expanded(IndexPath, expandingThumbnailWidthToHeight: CGFloat?)
        case collapsed
        
        var indexPathForExpandingItem: IndexPath? {
            switch self {
            case .expanded(let indexPath, _):
                return indexPath
            case .collapsed:
                return nil
            }
        }
    }
    
    let style: Style
    
    var expandedItemWidth: CGFloat?
    // 与 PhotoPreviewSelectedView 保持一致：90 - 10 (top inset) - 5 (bottom inset) = 75
    // iPad 上使用更大的尺寸：110 - 10 (top inset) - 5 (bottom inset) = 95
    static var collapsedItemWidth: CGFloat {
        UIDevice.isPad ? 95 : 75
    }
    
    private var attributesDictionary: [IndexPath: UICollectionViewLayoutAttributes] = [:]
    private var contentSize: CGSize = .zero
    
    init(style: Style) {
        self.style = style
        super.init()
    }
    
    required init?(coder: NSCoder) {
        self.style = .collapsed
        super.init(coder: coder)
    }
    
    // MARK: - Override
    
    override var collectionViewContentSize: CGSize {
        contentSize
    }
    
    override func prepare() {
        // Reset
        attributesDictionary.removeAll(keepingCapacity: true)
        contentSize = .zero
        
        guard let collectionView, collectionView.numberOfSections == 1 else { return }
        let numberOfItems = collectionView.numberOfItems(inSection: 0)
        guard numberOfItems > 0 else { return }
        
        // NOTE: Cache and reuse expandedItemWidth for smooth animation.
        let expandedItemWidth = self.expandedItemWidth ?? expandingItemWidth(in: collectionView)
        self.expandedItemWidth = expandedItemWidth
        
        
        let collapsedItemSpacing: CGFloat
        if #available(iOS 26.0, *), !PhotoManager.isIos26Compatibility  {
            collapsedItemSpacing = 3.0
        }else {
            collapsedItemSpacing = 1.0
        }
        let expandedItemSpacing = 12.0
        
        // Calculate frames for each item
        var frames: [IndexPath: CGRect] = [:]
        for item in 0..<numberOfItems {
            let indexPath = IndexPath(item: item, section: 0)
            let previousIndexPath = IndexPath(item: item - 1, section: 0)
            let width: CGFloat
            let itemSpacing: CGFloat
            switch style.indexPathForExpandingItem {
            case indexPath:
                width = expandedItemWidth
                itemSpacing = expandedItemSpacing
            case previousIndexPath:
                width = Self.collapsedItemWidth
                itemSpacing = expandedItemSpacing
            default:
                width = Self.collapsedItemWidth
                itemSpacing = collapsedItemSpacing
            }
            let previousFrame = frames[previousIndexPath]
            let x = previousFrame.map { $0.maxX + itemSpacing } ?? 0
            // cell 高度与 PhotoPreviewSelectedView 保持一致，iPad 上使用更大的尺寸
            let cellHeight: CGFloat = Self.collapsedItemWidth
            frames[indexPath] = CGRect(
                x: x,
                y: 0,
                width: width,
                height: cellHeight
            )
        }
        
        // Calculate the content size
        let lastItemFrame = frames[IndexPath(item: numberOfItems - 1, section: 0)]!
        contentSize = CGSize(
            width: lastItemFrame.maxX,
            height: collectionView.bounds.height
        )
        
        // Set up layout attributes
        for (indexPath, frame) in frames {
            let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
            attributes.frame = frame
            attributesDictionary[indexPath] = attributes
        }
    }
    
    private func expandingItemWidth(in collectionView: UICollectionView) -> CGFloat {
        // 固定宽度，不根据图片比例缩放
        return Self.collapsedItemWidth
    }
    
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        attributesDictionary.values.filter { $0.frame.intersects(rect) }
    }
    
    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        attributesDictionary[indexPath]
    }
    
    override func targetContentOffset(
        forProposedContentOffset proposedContentOffset: CGPoint
    ) -> CGPoint {
        let offset = super.targetContentOffset(
            forProposedContentOffset: proposedContentOffset
        )
        guard let collectionView else { 
            return offset
        }
        
        // Center the target item.
        let indexPathForCenterItem: IndexPath
        switch style {
        case .expanded(let indexPathForExpandingItem, _):
            indexPathForCenterItem = indexPathForExpandingItem
        case .collapsed:
            guard let indexPath = collectionView.indexPathForHorizontalCenterItem else {
                return offset
            }
            indexPathForCenterItem = indexPath
        }
        
        guard let centerItemAttributes = layoutAttributesForItem(at: indexPathForCenterItem) else {
            return offset
        }
        return CGPoint(
            x: centerItemAttributes.center.x - collectionView.bounds.width / 2,
            y: offset.y
        )
    }
}

extension UICollectionView {
    var indexPathForHorizontalCenterItem: IndexPath? {
        let centerX = CGPoint(x: contentOffset.x + bounds.width / 2, y: 0)
        return indexPathForItem(at: centerX)
    }
}
