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

    //���Ϊ�ӽڵ㣬����Ϊ�˿��Լ���ü�����
    if (m_Stencil)
    {
        addChild(m_Stencil);
    }

    return true;
}


void ClippingArea::setStencil(CCNode *stencil)
{
    //�жϵ�ǰ�Ĳü�ģ���Ƿ�Ϊ��ָ�룬���ǵĻ��Ƴ�
    if (m_Stencil)
    {
        removeChild(m_Stencil);
        CC_SAFE_RELEASE(m_Stencil);
    }

    m_Stencil = stencil;

    //�ǿյĻ������ӽڵ�
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
    //�ú���Ӧ�����Ѿ����븸�ڵ������²���ʹ��
    if (!getParent())
    {
        CCLog("ClippingArea::convertToWorldRect�����ڸ��ڵ�");

        return CCRectMake(0, 0, 0, 0);
    }

    CCRect box = m_Stencil->boundingBox();

    //��ȡ���½�����
    CCPoint posLB = ccp(box.origin.x, box.origin.y);
    //��ȡ���Ͻ�����
    CCPoint posRT = ccpAdd(posLB, ccp(box.size.width, box.size.height));

    //ת��Ϊ��������
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
    //�ж��Ƿ���Ҫ�ü�
    if (!isVisible() || !isClipping() || !m_Stencil)
    {
        //����Ҫ�ü��Ļ�ֱ��ִ��CCNode��visit����
        return CCNode::visit();
    }

    //�ü���ʼ
    beforeDraw();

    //ִ��CCNode
    CCNode::visit();
    
    //�ü�����
    afterDraw();
}


void ClippingArea::beforeDraw()
{
    //��ʼ�����ڵ�ü����򿪹�
    m_ScissorRestored = false;

    //��ȡ��������Ĳü������С
    CCRect rect = convertStencilToWorldRect();

    //�ж��Ƿ��Ѿ��򿪣��ǵĻ��͸����Ѿ������Ĳü���С���¼���ü���С
    if (CCEGLView::sharedOpenGLView()->isScissorEnabled()) 
    {
        //�򿪸��ڵ�ü��жϿ���
        m_ScissorRestored = true;
        //��ȡ�Ѿ����õĲü�����
        m_ParentScissorRect = CCEGLView::sharedOpenGLView()->getScissorRect();

        //���¼���ü�������������Ѿ������Ĳü��������棬˵�����Ĳü�����
        if (rect.intersectsRect(m_ParentScissorRect)) 
        {
            float x = MAX(rect.origin.x, m_ParentScissorRect.origin.x);
            float y = MAX(rect.origin.y, m_ParentScissorRect.origin.y);
            float xx = MIN(rect.origin.x+rect.size.width, m_ParentScissorRect.origin.x+m_ParentScissorRect.size.width);
            float yy = MIN(rect.origin.y+rect.size.height, m_ParentScissorRect.origin.y+m_ParentScissorRect.size.height);

            //���òü�����
            CCEGLView::sharedOpenGLView()->setScissorInPoints(x, y, xx-x, yy-y);
        }
    }
    else 
    {
        //�����ü���Ĭ�Ϲر�
        glEnable(GL_SCISSOR_TEST);

        //���òü�����
        CCEGLView::sharedOpenGLView()->setScissorInPoints(rect.origin.x, rect.origin.y, rect.size.width, rect.size.height);
    }
}


void ClippingArea::afterDraw()
{
    //�ж��Ƿ���Ҫ��ԭ���ڵ�Ĳü�
    if (m_ScissorRestored) {
        //restore the parent's scissor rect
        //��ԭ�ü�����
        CCEGLView::sharedOpenGLView()->setScissorInPoints(m_ParentScissorRect.origin.x, m_ParentScissorRect.origin.y, m_ParentScissorRect.size.width, m_ParentScissorRect.size.height);
    }
    else {
        //�رղü�
        glDisable(GL_SCISSOR_TEST);
    }
}