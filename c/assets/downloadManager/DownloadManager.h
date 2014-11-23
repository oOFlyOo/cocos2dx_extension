/** 
*	用于下载文件
*/


#ifndef _DOWNLOAD_MANAGER_H_
#define _DOWNLOAD_MANAGER_H_

#include "AssetsManager/AssetsManager.h"

#include "CCLuaEngine.h"


/**
*	注册回调函数对应的code
*/
enum UpdateCode
{
    kOnError,           //更新失败
    kOnProgress,        //更新进度
    kOnSuccess,         //更新成功
};


/** 
*	下载文件类
*/
class DownloadManager
{
public:
    /** 
    *	默认构造函数
    */
    DownloadManager(std::string packageUrl = NULL, std::string storagePath = NULL);
    /** 
    *	析构函数
    */
    virtual ~DownloadManager();

    /** 
    *	执行下载
    */
    virtual void update();

    /** 
    *	设置下载地址
    */
    void setPackageUrl(std::string packageUrl);
    /** 
    *	获取下载地址
    */
    std::string getPackageUrl(std::string packageUrl);

    /** 
    *	设置下载到的路径
    */
    void setStoragePath(std::string storagePath);
    /** 
    *	获取下载到的路径
    */
    std::string getStoragePath(std::string storagePaht);

    /** 
    *	设置连接时间
    */
    void setTimeout(unsigned int timeout);
    /** 
    *	获取连接时间
    */
    unsigned int getTimeout(unsigned int timeout);

    /** 
    *	设置委托
    */
    void setDelegate(cocos2d::extension::AssetsManagerDelegateProtocol *delegate);

protected:
    /** 
    *   将下载地址转换为临时地址
    */
    void changToTmpPath();

    /** 
    *	输出错误信息
    */
    void sendErrorMessage(cocos2d::extension::AssetsManager::ErrorCode error);

    /** 
    *	下载处理
    */
    static void *assetsDownload(void *data);
    /** 
    *	执行下载
    */
    virtual bool download();
    /** 
    *	下载包
    */
    static size_t downLoadPackage(void *ptr, size_t size, size_t nmemb, void *userdata);
    /** 
    *	进度
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

    //下载Url
    std::string m_packageUrl;
    //下载位置
    std::string m_storagePath;
    //tmp地址
    std::string m_tmpPath;
    //连接时间
    unsigned int m_timeout;

    //回调委托，弱引用
    cocos2d::extension::AssetsManagerDelegateProtocol *m_delegate;

    CURL *m_curl;
    Helper *_schedule;
    pthread_t *m_tid;
};


/**
 *	继承于AssetsManagerDelegateProtocol
*/
class AssetsManagerDelegate:public cocos2d::extension::AssetsManagerDelegateProtocol
{
public:
    /**
    *	默认构造函数
    */
    AssetsManagerDelegate();
    /**
    *	默认析构函数
    */
    virtual ~AssetsManagerDelegate();

    /** 
    *   更新失败时候的回调函数
    */
    virtual void onError(cocos2d::extension::AssetsManager::ErrorCode errorCode);
    /** 
    *   更新进度回调函数
    */
    virtual void onProgress(int percent);
    /** 
    *   更新成功时候的回调函数
    */
    virtual void onSuccess();

    /**
    *	注册及取消回调
    */
    virtual void registerUpdateHandler(int handler, UpdateCode code);
    virtual void unRegisterUpdateHandler(UpdateCode code);

protected:
    /**
    *	获取Lua栈
    */
    cocos2d::CCLuaStack *getLuaStack();

    //更新失败回调
    int m_errorHandler;
    //更新进度回调
    int m_progressHandler;
    //更新成功回调
    int m_successHandler;
};


#endif  //_DOWNLOAD_MANAGER_H_