#include "DownloadManager.h"
#include "Manager/FileManager/FileManager.h"
using namespace std;

#include "cocos2d.h"
USING_NS_CC;


// Message type
#define ASSETSMANAGER_MESSAGE_UPDATE_SUCCEED                0
#define ASSETSMANAGER_MESSAGE_RECORD_DOWNLOADED_VERSION     1
#define ASSETSMANAGER_MESSAGE_PROGRESS                      2
#define ASSETSMANAGER_MESSAGE_ERROR                         3


struct ErrorMessage
{
    cocos2d::extension::AssetsManager::ErrorCode code;
    DownloadManager* manager;
};


struct ProgressMessage
{
    int percent;
    DownloadManager* manager;
};


DownloadManager::DownloadManager(std::string packageUrl /*= NULL*/, std::string storagePath /*= NULL*/):
    m_packageUrl(packageUrl),
    m_storagePath(storagePath),
    m_timeout(0),
    m_delegate(NULL),
    m_curl(NULL),
    m_tid(NULL)
{
//     changToTmpPath();
    _schedule = new Helper();
}


DownloadManager::~DownloadManager()
{

}


void DownloadManager::setPackageUrl(std::string packageUrl)
{
    m_packageUrl = packageUrl;
}


std::string DownloadManager::getPackageUrl(std::string packageUrl)
{
    return m_packageUrl;
}

void DownloadManager::setStoragePath(std::string storagePath)
{
    m_storagePath = storagePath;

    changToTmpPath();
}


void DownloadManager::changToTmpPath()
{
    m_tmpPath = m_storagePath + ".tmp";
}


std::string DownloadManager::getStoragePath(std::string storagePaht)
{
    return m_storagePath;
}


void DownloadManager::setTimeout(unsigned int timeout)
{
    m_timeout = timeout;
}


unsigned int DownloadManager::getTimeout(unsigned int timeout)
{
    return m_timeout;
}


void DownloadManager::setDelegate(cocos2d::extension::AssetsManagerDelegateProtocol *delegate)
{
    m_delegate = delegate;
}


void DownloadManager::update()
{
    if (m_tid)
    {
        return;
    }

    if (m_packageUrl.size() == 0 || m_storagePath.size() == 0)
    {
        CCLog("下载Url或者Path出错！");

        return;
    }

    // 需要先转换地址
    changToTmpPath();

    m_tid = new pthread_t();
    pthread_create(&(*m_tid), NULL, assetsDownload, this);
}


void * DownloadManager::assetsDownload(void *data)
{
    DownloadManager *self = (DownloadManager *)data;

    if (self->download())
    {
        //转换文件，成功便删除缓存文件        
        if (FileManager::getInstance()->copyFile(self->m_tmpPath, self->m_storagePath))
        {
            FileManager::getInstance()->deleteFile(self->m_tmpPath);
        }

        // Record updated version and remove downloaded zip file
        DownloadManager::Message *msg2 = new DownloadManager::Message();
        msg2->what = ASSETSMANAGER_MESSAGE_UPDATE_SUCCEED;
        msg2->obj = self;
        self->_schedule->sendMessage(msg2);
    }

    if (self->m_tid)
    {
        delete self->m_tid;
        self->m_tid = NULL;
    }

    return NULL;
}


bool DownloadManager::download()
{
    FILE *fp = fopen(m_tmpPath.c_str(), "wb");
    if (! fp)
    {
        sendErrorMessage(cocos2d::extension::AssetsManager::kCreateFile);
        CCLog("can not create file %s", m_tmpPath.c_str());
        return false;
    }

    m_curl = curl_easy_init();
    if (! m_curl)
    {
        sendErrorMessage(cocos2d::extension::AssetsManager::kNetwork);
        CCLOG("can not init curl");
        return false;
    }

    // Download pacakge
    CURLcode res;
    curl_easy_setopt(m_curl, CURLOPT_URL, m_packageUrl.c_str());
    curl_easy_setopt(m_curl, CURLOPT_SSL_VERIFYPEER, 0L);
    curl_easy_setopt(m_curl, CURLOPT_WRITEFUNCTION, downLoadPackage);
    curl_easy_setopt(m_curl, CURLOPT_WRITEDATA, fp);
    curl_easy_setopt(m_curl, CURLOPT_NOPROGRESS, false);
    curl_easy_setopt(m_curl, CURLOPT_PROGRESSFUNCTION, progressFunc);
    curl_easy_setopt(m_curl, CURLOPT_PROGRESSDATA, this);
    if (m_timeout) 
    {
        curl_easy_setopt(m_curl, CURLOPT_CONNECTTIMEOUT, m_timeout);
    }
    res = curl_easy_perform(m_curl);
    curl_easy_cleanup(m_curl);
    if (res != 0)
    {
        sendErrorMessage(cocos2d::extension::AssetsManager::kNetwork);
        CCLog("error when download package");
        fclose(fp);

        //删除缓存文件
        FileManager::getInstance()->deleteFile(m_tmpPath);

        return false;
    }

    CCLog("succeed downloading package %s", m_packageUrl.c_str());

    fclose(fp);
    return true;
}


void DownloadManager::sendErrorMessage(cocos2d::extension::AssetsManager::ErrorCode error)
{
    Message *msg = new Message();
    msg->what = ASSETSMANAGER_MESSAGE_ERROR;

    ErrorMessage *errorMessage = new ErrorMessage();
    errorMessage->code = error;
    errorMessage->manager = this;
    msg->obj = errorMessage;

    _schedule->sendMessage(msg);
}


size_t DownloadManager::downLoadPackage(void *ptr, size_t size, size_t nmemb, void *userdata)
{
    FILE *fp = (FILE*)userdata;
    size_t written = fwrite(ptr, size, nmemb, fp);
    return written;
}

int DownloadManager::progressFunc(void *ptr, double totalToDownload, double nowDownloaded, double totalToUpLoad, double nowUpLoaded)
{
    DownloadManager* manager = (DownloadManager*)ptr;
    
    int progress = (int)(nowDownloaded/totalToDownload*100);

    if (manager->m_delegate)
    {
        manager->m_delegate->onProgress(progress);
    }

    CCLog("downloading... %d%%", (int)(nowDownloaded/totalToDownload*100));

    return 0;
}


// Implementation of AssetsManagerHelper

DownloadManager::Helper::Helper()
{
    _messageQueue = new list<Message*>();
    pthread_mutex_init(&_messageQueueMutex, NULL);
    CCDirector::sharedDirector()->getScheduler()->scheduleUpdateForTarget(this, 0, false);
}

DownloadManager::Helper::~Helper()
{
    CCDirector::sharedDirector()->getScheduler()->unscheduleAllForTarget(this);
    delete _messageQueue;
}

void DownloadManager::Helper::sendMessage(Message *msg)
{
    pthread_mutex_lock(&_messageQueueMutex);
    _messageQueue->push_back(msg);
    pthread_mutex_unlock(&_messageQueueMutex);
}

void DownloadManager::Helper::update(float dt)
{
    Message *msg = NULL;

    // Returns quickly if no message
    pthread_mutex_lock(&_messageQueueMutex);
    if (0 == _messageQueue->size())
    {
        pthread_mutex_unlock(&_messageQueueMutex);
        return;
    }

    // Gets message
    msg = *(_messageQueue->begin());
    _messageQueue->pop_front();
    pthread_mutex_unlock(&_messageQueueMutex);

    switch (msg->what) {
    case ASSETSMANAGER_MESSAGE_UPDATE_SUCCEED:
        handleUpdateSucceed(msg);

        break;
    case ASSETSMANAGER_MESSAGE_PROGRESS:
        if (((ProgressMessage*)msg->obj)->manager->m_delegate)
        {
            ((ProgressMessage*)msg->obj)->manager->m_delegate->onProgress(((ProgressMessage*)msg->obj)->percent);
        }

        delete (ProgressMessage*)msg->obj;

        break;
    case ASSETSMANAGER_MESSAGE_ERROR:
        // error call back
        if (((ErrorMessage*)msg->obj)->manager->m_delegate)
        {
            ((ErrorMessage*)msg->obj)->manager->m_delegate->onError(((ErrorMessage*)msg->obj)->code);
        }

        delete ((ErrorMessage*)msg->obj);

        break;
    default:
        break;
    }

    delete msg;
}

void DownloadManager::Helper::handleUpdateSucceed(Message *msg)
{
    DownloadManager* manager = (DownloadManager*)msg->obj;

    if (manager->m_delegate) manager->m_delegate->onSuccess();
}


AssetsManagerDelegate::AssetsManagerDelegate():m_errorHandler(0), 
    m_progressHandler(0),
    m_successHandler(0)
{

}


AssetsManagerDelegate::~AssetsManagerDelegate()
{
    unRegisterUpdateHandler(kOnError);
    unRegisterUpdateHandler(kOnProgress);
    unRegisterUpdateHandler(kOnSuccess);
}


void AssetsManagerDelegate::onError(cocos2d::extension::AssetsManager::ErrorCode errorCode)
{
    if (m_errorHandler)
    {
        CCLuaStack *luaStack = getLuaStack();
        luaStack->pushInt(errorCode);
        luaStack->executeFunctionByHandler(m_errorHandler, 1);
    }
}


void AssetsManagerDelegate::onProgress(int percent)
{
    if (m_progressHandler)
    {
        CCLuaStack *luaStack = getLuaStack();
        luaStack->pushInt(percent);
        luaStack->executeFunctionByHandler(m_progressHandler, 1);
    }
}


void AssetsManagerDelegate::onSuccess()
{
    if (m_successHandler)
    {
        CCLuaStack *luaStack = getLuaStack();

        luaStack->executeFunctionByHandler(m_successHandler, 0);
    }
}


void AssetsManagerDelegate::registerUpdateHandler(int handler, UpdateCode code)
{
    //以防已经注册了相同的函数，先取消注册
    unRegisterUpdateHandler(code);

    //这只是注册一种函数，可以根据需求进行不同函数的注册，当然这里的写法就会相应的复杂
    switch(code)
    {
    case kOnError:
        {
            m_errorHandler = handler;
            break;
        }
    case kOnProgress:
        {
            m_progressHandler = handler;
            break;
        }
    case kOnSuccess:
        {
            m_successHandler = handler;
            break;
        }
    default:
        {
            break;
        }
    }
}


void AssetsManagerDelegate::unRegisterUpdateHandler(UpdateCode code)
{
    //保存临时值 
    int handler = 0;

    switch(code)
    {
    case kOnError:
        {
            handler = m_errorHandler;
            break;
        }
    case kOnProgress:
        {
            handler = m_progressHandler;
            break;
        }
    case kOnSuccess:
        {
            handler = m_successHandler;
            break;
        }
    default:
        {
            break;
        }
    }

    //仅当有注册的情况下执行
    if (handler)
    {
        switch(code)
        {
        case kOnError:
            {
                m_errorHandler = 0;
                break;
            }
        case kOnProgress:
            {
                m_progressHandler = 0;
                break;
            }
        case kOnSuccess:
            {
                m_successHandler = 0;
                break;
            }
        default:
            {
                break;
            }
        }

        CCScriptEngineManager::sharedManager()->getScriptEngine()->removeScriptHandler(handler);
    }
}


cocos2d::CCLuaStack * AssetsManagerDelegate::getLuaStack()
{
    CCLuaEngine* pEngine = CCLuaEngine::defaultEngine();
    return pEngine->getLuaStack();
}