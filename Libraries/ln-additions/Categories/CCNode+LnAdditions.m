//
// Created by knight on 02/02/2013.
//
// Contact me via Email(dlnathos321@gmail.com) or Twitter(@dailingnan)
//


#import "CCNode+LnAdditions.h"
#import "Body.h"
#import <objc/runtime.h>

// dynamically access the components array
static char const *const nodeComponentKey = "CCNodeExtension.CCCompoonent";

@implementation CCNode (LnAdditions)
@dynamic rootComponent;
@dynamic body;

#pragma mark - More initializer

+ (id)nodeWithRootComponent:(CCComponent *)comp {
    CCNode *n = [self node];
    n.rootComponent = comp;
    return n;
}

#pragma mark - Normal extension

- (BOOL)fullyOutsideScreen {
    CGPoint worldCoord = [self.parent convertToWorldSpace:self.position];
    return worldCoord.x + (1 - self.anchorPoint.x) * self.contentSize.width < 0 || worldCoord.x - self.anchorPoint.x * self.contentSize.width > [CCDirector sharedDirector].winSize.width
            || worldCoord.y + (1 - self.anchorPoint.y) * self.contentSize.height < 0 || worldCoord.y - self.anchorPoint.y * self.contentSize.height > [CCDirector sharedDirector].winSize.height;
}

- (BOOL)fullyInsideScreen {
    CGPoint worldCoord = [self.parent convertToWorldSpace:self.position];
    return worldCoord.x - self.anchorPoint.x * self.contentSize.width >= 0 && worldCoord.x + (1 - self.anchorPoint.x) * self.contentSize.width <= [CCDirector sharedDirector].winSize.width
            && worldCoord.y - self.anchorPoint.y * self.contentSize.height >= 0 && worldCoord.y + (1 - self.anchorPoint.y) * self.contentSize.height <= [CCDirector sharedDirector].winSize.height;
}

- (CGFloat)minXEdgePosition {
    return self.position.x - self.contentSize.width * self.anchorPoint.x;
}

- (CGFloat)maxXEdgePosition {
    return self.position.x + self.contentSize.width * (1 - self.anchorPoint.x);
}

- (CGFloat)minYEdgePosition {
    return self.position.y - self.contentSize.height * self.anchorPoint.y;
}

- (CGFloat)maxYEdgePosition {
    return self.position.y + self.contentSize.height * (1 - self.anchorPoint.y);
}

- (CGSize)winSize {
    return [CCDirector sharedDirector].winSize;
}

- (id)objectAtIndexedSubscript:(NSInteger)tag {
    return [self getChildByTag:tag];
}

- (void)setObject:(CCNode *)node atIndexedSubscript:(NSInteger)tag {
    [self addChild:node z:0 tag:tag];
}

#pragma mark - Anchor point related operations

/**
* This method will return the new anchor point calculated from traversing
* from the current anchor point by the 'delta' amount of point
* The size of the node is measured by the contentSize
* That's why this method might only be useful if the content size is defined
*/
- (CGPoint)anchorPointFromDeltaPoint:(CGPoint)delta {
    CGFloat width = self.contentSize.width;
    CGFloat height = self.contentSize.height;
    return ccpAdd(self.anchorPoint,
            ccp(width ? delta.x / width : 0, height ? delta.y / height : 0));
}

#pragma mark - Operations

- (BOOL)isAscendantOfNode:(CCNode *)node {
    if (node == self)
        return NO;
    CCNode *p;
    while ((p = node.parent)) {
        if (p == self)
            return YES;
    }
    return NO;
}

- (BOOL)isDescendantOfNode:(CCNode *)node {
    return [node isAscendantOfNode:self];
}

- (BOOL)isOnLineageOfNode:(CCNode *)node {
    return node == self || [self isAscendantOfNode:node] || [self isDescendantOfNode:node];
}

/** return all the nodes on this lineage */
- (NSArray *)allLineages {
    NSMutableArray *arr = [NSMutableArray array];
    // get all the parents first
    CCNode *n = self;
    do
        [arr addObject:n];
    while ((n = n.parent));
    // add all the children
    return [arr arrayByAddingObjectsFromArray:self.allDescendants];
}

- (NSArray *)allAscendants {
    NSMutableArray *arr = [NSMutableArray array];
    CCNode *n = self;
    while ((n = n.parent)) {
        [arr addObject:n];
    }
    return arr;
}

- (NSArray *)allDescendants {
    NSMutableArray *arr = [NSMutableArray array];
    [arr addObjectsFromArray:self.children.getNSArray];
    for (CCNode *c in self.children) {
        [arr addObjectsFromArray:c.allDescendants];
    }
    return arr;
}

// chained methods
- (id)nodeWithAnchorPoint:(CGPoint)anchor {
    self.anchorPoint = anchor;
    return self;
}

// return a sprite with flipped
- (void)flipInnerX {
    self.scaleX *= -1;
    CGPoint an = self.anchorPoint;
    // the anchorPoint should reflect about an.x = 0.5
    an.x = 1 - an.x;
    self.anchorPoint = an;
}

- (void)flipInnerY {
    self.scaleY *= -1;
    CGPoint an = self.anchorPoint;
    // the anchorPoint should reflect about an.x = 0.5
    an.y = 1 - an.y;
    self.anchorPoint = an;
}

- (void)addChildren:(id <NSFastEnumeration>)children {
    for (CCNode *c in children)
        [self addChild:c];
}

#pragma mark - Worldspace size calculation

// we should really return the box measured at this level / in the coordinates system of this
// node. In other words, how large is the node as measured in the current space..?
- (CGRect)unionBox {
    CGRect un = (CGRect) {{0, 0}, self.contentSize};
    for (CCNode *node in self.children) {
        // we have to be careful about the anchor points as well
        un = CGRectUnion(un, CGRectApplyAffineTransform(node.unionBox, node.nodeToParentTransform));
    }
    // we obtain the rect
    // note that this rect might not only include the rect of the subnodes in the first
    // quadron. In fact, it's the union of all the node's size in this coordinate system
    return un;
}

// the unioned boundingBox in the world coordinates
- (CGRect)unionBoxInWorld {
    return CGRectApplyAffineTransform(self.unionBox, self.nodeToWorldTransform);
}

// this is the unioned space viewed in the parent space
- (CGRect)unionBoxInParent {
    return CGRectApplyAffineTransform(self.unionBox, self.nodeToParentTransform);
}

- (NSSet *)keyPathsForValuesAffectingUnionBox {
    return [NSSet setWithObjects:@"scaleX", @"scaleY", @"anchorPoint", @"children", @"contentSize", nil];
}

#pragma mark - Components

- (CCComponent *)rootComponent {
    CCComponent *component = objc_getAssociatedObject(self, nodeComponentKey);
    // lazy instantiation
    if (!component || component.host != self)
        self.rootComponent = component = [CCComponent component];
    return component;
}

- (void)setRootComponent:(CCComponent *)rootComponent {
    rootComponent.host = self;
    objc_setAssociatedObject(self, nodeComponentKey, rootComponent, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (id)forwardingTargetForSelector:(SEL)aSelector {
    return self.rootComponent;
}

#pragma mark - Body

// lazy instantiation of a TranslationalBody
- (Body *)body {
    Body *m = [self.rootComponent childForClass:[Body class]];
    if (!m)
        [self.rootComponent addChild:m = [Body body]];
    return m;
}

- (void)setBody:(Body *)body {
    [self.rootComponent setChild:body forClassLock:[Body class]];
}

@end