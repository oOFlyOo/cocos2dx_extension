#ifndef _CLIPPINGAREA_H_
#define _CLIPPINGAREA_H_


#include "base_nodes/CCNode.h"


/** ����CCClippingNodeд�Ĳü��ڵ�
    ������ƣ������ڲ�ʵ�ֲ�ͬ
    ֻ�ܼ򵥵�ʵ�ֳ���������Ĳü�
    �ü�ģ�彫���ΪClippingArea���ӽڵ㣬���������ش���
    ��ClippingArea������һ����СΪ(1, 1)��CCNode

    �����ǿ��Լ̳�CCClippingNode�ģ�������ֻ����дvisit��������
    �������������������
*/
class ClippingArea:public cocos2d::CCNode
{
public:
    /** �½�һ���յģ��ں�������
    */
    static ClippingArea *create();
    /** ��һ���ü�ģ���½�
    */
    static ClippingArea *create(cocos2d::CCNode *stencil);

    /** ��������
    */
    virtual ~ClippingArea();

    /** ��ʼ����û�вü�ģ��
    */
    virtual bool init();
    /** ��ʼ����ʹ�òü�ģ��
    */
    virtual bool init(cocos2d::CCNode *stencil);

    /** ���òü�ģ��
    */
    void setStencil(cocos2d::CCNode *stencil);
    /** ��ȡ�ü�ģ�����
    */
    cocos2d::CCNode *getStencil() const;
    
    /** ���òü������С
    */
    void setClippingSize(cocos2d::CCSize size);
    /** ���زü������С
    */
    cocos2d::CCSize getClippingSize();

    //ת���ü�����Ϊ��������
    cocos2d::CCRect convertStencilToWorldRect();

    /** �����Ƿ����òü�
    */
    void setIsClipping(bool isClipping);
    /** �����Ƿ����òü�
    */
    bool isClipping();

    /** �̳�visit��������д���ﵽ�ü���Ŀ��
    */
    virtual void visit();
    /** ����ü����򣬲��ҿ����ü�
    */
    virtual void beforeDraw();
    /** �رղü���
    */
    virtual void afterDraw();

protected:
    /** Ĭ�Ϲ��캯��
    */
    ClippingArea();

    //�����Ƿ�ü���Ĭ�Ͽ���
    bool m_IsClipping;

    //�ü�ģ��
    cocos2d::CCNode *m_Stencil;

    //�Ƿ���Ҫ�ָ��ü��������ڸ��ڵ㿪���˲ü������
    bool m_ScissorRestored;
    //���ڵ�Ĳü�����
    cocos2d::CCRect m_ParentScissorRect;
};


#endif