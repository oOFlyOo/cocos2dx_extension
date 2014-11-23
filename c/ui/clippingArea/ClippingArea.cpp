#include "ClippingArea.h"
#include "cocos2d.h"
#include "CCEGLView.h"

USING_NS_CC;


ClippingArea::ClippingArea():m_Stencil(NULL), m_IsClipping(true)
{
    CC_SAFE_RELEASE(m_Stencil);
}


ClippingArea::~ClippingArea()
{
    m_Stencil = NULL;
}


ClippingArea *ClippingArea::create()
{
    ClippingArea *instance = new ClippingArea();
    if (instance && instance->init())
    {
        instance->autorelease();
    }
    else
    {
        CC_SAFE_DELETE(instance);
    }

    return instance;
}


ClippingArea *ClippingArea::create(CCNode *stencil)
{
    ClippingArea *instance = new ClippingArea();
    if (instance && instance->init(stencil))
    {
        instance->autorelease();
    }
    else
    {
        CC_SAFE_DELETE(instance);
    }

    return instance;
}


bool ClippingArea::init()
{
    return init(NULL);
}


bool ClippingArea::init(CCNode *stencil)
{
    m_Stencil = stencil;
    CC_SAFE_RELEASE(m_Stencil);

    //添加为子节点，这是为了可以计算裁剪区域
    if (m_Stencil)
    {
        addChild(m_Stencil);
    }

    return true;
}


void ClippingArea::setStencil(CCNode *stencil)
{
    //判断当前的裁剪模板是否为空指针，不是的话移除
    if (m_Stencil)
    {
        removeChild(m_Stencil);
        CC_SAFE_RELEASE(m_Stencil);
    }

    m_Stencil = stencil;

    //非空的话加入子节点
    if (m_Stencil)
    {
        CC_SAFE_RETAIN(m_Stencil);
        addChild(m_Stencil);
    }
}


CCNode *ClippingArea::getStencil() const
{
    return m_Stencil;
}


void ClippingArea::setClippingSize(CCSize size)
{
    if (m_Stencil)
    {
        m_Stencil->setContentSize(size);
    }
}


CCRect ClippingArea::convertStencilToWorldRect()
{
    //该函数应该在已经加入父节点的情况下才能使用
    if (!getParent())
    {
        CCLog("ClippingArea::convertToWorldRect不存在父节点");

        return CCRectMake(0, 0, 0, 0);
    }

    CCRect box = m_Stencil->boundingBox();

    //获取左下角坐标
    CCPoint posLB = ccp(box.origin.x, box.origin.y);
    //获取右上角坐标
    CCPoint posRT = ccpAdd(posLB, ccp(box.size.width, box.size.height));

    //转换为世界坐标
    CCPoint posLBW = convertToWorldSpaceAR(posLB);
    CCPoint posRTW = convertToWorldSpaceAR(posRT);
    
    return CCRectMake(posLBW.x, posLBW.y, posRTW.x - posLBW.x, posRTW.y - posLBW.y);
}


CCSize ClippingArea::getClippingSize()
{
    return m_Stencil->getContentSize();
}


void ClippingArea::setIsClipping(bool isClipping)
{
    m_IsClipping = isClipping;
}


bool ClippingArea::isClipping()
{
    return m_IsClipping;
}


void ClippingArea::visit()
{
    //判断是否需要裁剪
    if (!isVisible() || !isClipping() || !m_Stencil)
    {
        //不需要裁剪的话直接执行CCNode的visit函数
        return CCNode::visit();
    }

    //裁减开始
    beforeDraw();

    //执行CCNode
    CCNode::visit();
    
    //裁减结束
    afterDraw();
}


void ClippingArea::beforeDraw()
{
    //初始化父节点裁剪区域开关
    m_ScissorRestored = false;

    //获取世界坐标的裁剪区域大小
    CCRect rect = convertStencilToWorldRect();

    //判断是否已经打开，是的话就根据已经开启的裁剪大小重新计算裁剪大小
    if (CCEGLView::sharedOpenGLView()->isScissorEnabled()) 
    {
        //打开父节点裁剪判断开关
        m_ScissorRestored = true;
        //获取已经设置的裁剪区域
        m_ParentScissorRect = CCEGLView::sharedOpenGLView()->getScissorRect();

        //重新计算裁剪区域，如果不在已经开启的裁剪区域里面，说明更改裁剪区域
        if (rect.intersectsRect(m_ParentScissorRect)) 
        {
            float x = MAX(rect.origin.x, m_ParentScissorRect.origin.x);
            float y = MAX(rect.origin.y, m_ParentScissorRect.origin.y);
            float xx = MIN(rect.origin.x+rect.size.width, m_ParentScissorRect.origin.x+m_ParentScissorRect.size.width);
            float yy = MIN(rect.origin.y+rect.size.height, m_ParentScissorRect.origin.y+m_ParentScissorRect.size.height);

            //设置裁剪区域
            CCEGLView::sharedOpenGLView()->setScissorInPoints(x, y, xx-x, yy-y);
        }
    }
    else 
    {
        //开启裁剪，默认关闭
        glEnable(GL_SCISSOR_TEST);

        //设置裁剪区域
        CCEGLView::sharedOpenGLView()->setScissorInPoints(rect.origin.x, rect.origin.y, rect.size.width, rect.size.height);
    }
}


void ClippingArea::afterDraw()
{
    //判断是否需要还原父节点的裁剪
    if (m_ScissorRestored) {
        //restore the parent's scissor rect
        //还原裁剪区域
        CCEGLView::sharedOpenGLView()->setScissorInPoints(m_ParentScissorRect.origin.x, m_ParentScissorRect.origin.y, m_ParentScissorRect.size.width, m_ParentScissorRect.size.height);
    }
    else {
        //关闭裁剪
        glDisable(GL_SCISSOR_TEST);
    }
}