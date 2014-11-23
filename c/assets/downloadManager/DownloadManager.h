/** 
*	���������ļ�
*/


#ifndef _DOWNLOAD_MANAGER_H_
#define _DOWNLOAD_MANAGER_H_

#include "AssetsManager/AssetsManager.h"

#include "CCLuaEngine.h"


/**
*	ע��ص�������Ӧ��code
*/
enum UpdateCode
{
    kOnError,           //����ʧ��
    kOnProgress,        //���½���
    kOnSuccess,         //���³ɹ�
};


/** 
*	�����ļ���
*/
class DownloadManager
{
public:
    /** 
    *	Ĭ�Ϲ��캯��
    */
    DownloadManager(std::string packageUrl = NULL, std::string storagePath = NULL);
    /** 
    *	��������
    */
    virtual ~DownloadManager();

    /** 
    *	ִ������
    */
    virtual void update();

    /** 
    *	�������ص�ַ
    */
    void setPackageUrl(std::string packageUrl);
    /** 
    *	��ȡ���ص�ַ
    */
    std::string getPackageUrl(std::string packageUrl);

    /** 
    *	�������ص���·��
    */
    void setStoragePath(std::string storagePath);
    /** 
    *	��ȡ���ص���·��
    */
    std::string getStoragePath(std::string storagePaht);

    /** 
    *	��������ʱ��
    */
    void setTimeout(unsigned int timeout);
    /** 
    *	��ȡ����ʱ��
    */
    unsigned int getTimeout(unsigned int timeout);

    /** 
    *	����ί��
    */
    void setDelegate(cocos2d::extension::AssetsManagerDelegateProtocol *delegate);

protected:
    /** 
    *   �����ص�ַת��Ϊ��ʱ��ַ
    */
    void changToTmpPath();

    /** 
    *	���������Ϣ
    */
    void sendErrorMessage(cocos2d::extension::AssetsManager::ErrorCode error);

    /** 
    *	���ش���
    */
    static void *assetsDownload(void *data);
    /** 
    *	ִ������
    */
    virtual bool download();
    /** 
    *	���ذ�
    */
    static size_t downLoadPackage(void *ptr, size_t size, size_t nmemb, void *userdata);
    /** 
    *	����
    */
    static int progressFunc(void *ptr, double totalToDownload, double nowDownloaded, double totalToUpLoad, double nowUpLoaded);

private:
    typedef struct _Message
    {
    public:
        _Message() : what(0), obj(NULL){}
        unsigned int what; // message type
        void* obj;
    } Message;

    class Helper : public cocos2d::CCObject
    {
    public:
        Helper();
        ~Helper();

        virtual void update(float dt);
        void sendMessage(Message *msg);

    private:
        void handleUpdateSucceed(Message *msg);

        std::list<Message*> *_messageQueue;
        pthread_mutex_t _messageQueueMutex;
    };

    //����Url
    std::string m_packageUrl;
    //����λ��
    std::string m_storagePath;
    //tmp��ַ
    std::string m_tmpPath;
    //����ʱ��
    unsigned int m_timeout;

    //�ص�ί�У�������
    cocos2d::extension::AssetsManagerDelegateProtocol *m_delegate;

    CURL *m_curl;
    Helper *_schedule;
    pthread_t *m_tid;
};


/**
 *	�̳���AssetsManagerDelegateProtocol
*/
class AssetsManagerDelegate:public cocos2d::extension::AssetsManagerDelegateProtocol
{
public:
    /**
    *	Ĭ�Ϲ��캯��
    */
    AssetsManagerDelegate();
    /**
    *	Ĭ����������
    */
    virtual ~AssetsManagerDelegate();

    /** 
    *   ����ʧ��ʱ��Ļص�����
    */
    virtual void onError(cocos2d::extension::AssetsManager::ErrorCode errorCode);
    /** 
    *   ���½��Ȼص�����
    */
    virtual void onProgress(int percent);
    /** 
    *   ���³ɹ�ʱ��Ļص�����
    */
    virtual void onSuccess();

    /**
    *	ע�ἰȡ���ص�
    */
    virtual void registerUpdateHandler(int handler, UpdateCode code);
    virtual void unRegisterUpdateHandler(UpdateCode code);

protected:
    /**
    *	��ȡLuaջ
    */
    cocos2d::CCLuaStack *getLuaStack();

    //����ʧ�ܻص�
    int m_errorHandler;
    //���½��Ȼص�
    int m_progressHandler;
    //���³ɹ��ص�
    int m_successHandler;
};


#endif  //_DOWNLOAD_MANAGER_H_