#ifndef _CLIPPINGAREA_H_
#define _CLIPPINGAREA_H_


#include "base_nodes/CCNode.h"


/** 仿照CCClippingNode写的裁剪节点
    框架相似，但是内部实现不同
    只能简单的实现长方形区域的裁剪
    裁剪模板将会成为ClippingArea的子节点，这点必须慎重处理
    而ClippingArea将会是一个大小为(1, 1)的CCNode

    本来是可以继承CCClippingNode的，这样子只需重写visit函数即可
    可这样会给别人造成误解
*/
class ClippingArea:public cocos2d::CCNode
{
public:
    /** 新建一个空的，在后面设置
    */
    static ClippingArea *create();
    /** 从一个裁剪模板新建
    */
    static ClippingArea *create(cocos2d::CCNode *stencil);

    /** 析构函数
    */
    virtual ~ClippingArea();

    /** 初始化，没有裁剪模板
    */
    virtual bool init();
    /** 初始化，使用裁剪模板
    */
    virtual bool init(cocos2d::CCNode *stencil);

    /** 设置裁剪模板
    */
    void setStencil(cocos2d::CCNode *stencil);
    /** 获取裁剪模板对象
    */
    cocos2d::CCNode *getStencil() const;
    
    /** 设置裁剪区域大小
    */
    void setClippingSize(cocos2d::CCSize size);
    /** 返回裁剪区域大小
    */
    cocos2d::CCSize getClippingSize();

    //转换裁剪区域为世界区域
    cocos2d::CCRect convertStencilToWorldRect();

    /** 设置是否启用裁剪
    */
    void setIsClipping(bool isClipping);
    /** 返回是否启用裁剪
    */
    bool isClipping();

    /** 继承visit函数，重写来达到裁剪的目的
    */
    virtual void visit();
    /** 计算裁剪区域，并且开启裁剪
    */
    virtual void beforeDraw();
    /** 关闭裁剪区
    */
    virtual void afterDraw();

protected:
    /** 默认构造函数
    */
    ClippingArea();

    //设置是否裁剪，默认开启
    bool m_IsClipping;

    //裁剪模板
    cocos2d::CCNode *m_Stencil;

    //是否需要恢复裁剪区域，用于父节点开启了裁剪的情况
    bool m_ScissorRestored;
    //父节点的裁剪区域
    cocos2d::CCRect m_ParentScissorRect;
};


#endif