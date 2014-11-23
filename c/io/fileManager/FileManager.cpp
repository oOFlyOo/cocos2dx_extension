#include "FileManager.h"

#include "cocos2d.h"
USING_NS_CC;

#if (CC_TARGET_PLATFORM != CC_PLATFORM_WIN32)
#include <dirent.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <errno.h>
#endif
using namespace std;


FileManager *FileManager::m_instance = NULL;


FileManager::FileManager()
{

}


FileManager::~FileManager()
{
    destroyInstance();
}


FileManager *FileManager::getInstance()
{
    if(!m_instance)
    {
        m_instance = new FileManager;
    }
    return m_instance;
}


void FileManager::destroyInstance()
{
    if (!m_instance)
    {
        delete m_instance;
        m_instance = NULL;
    }
}

string FileManager::convertPath(std::string path, int pos)
{
#if CC_TARGET_PLATFORM == CC_PLATFORM_WIN32
    int nPos = path.find("/", pos);
    if (nPos >= 0)
    {
        path.replace(nPos, 1, "\\");
        return convertPath(path, nPos + 1);
    }
    else
    {
        return path;
    }
#else
    int nPos = path.find("\\", pos);
    if (nPos >= 0)
    {
        path.replace(nPos, 1, "/");
        return convertPath(path, nPos + 1);
    }
    else
    {
        return path;
    }
#endif
}

bool FileManager::copyFile(std::string originPath, std::string newPath)
{    
    //检查文件是否存在
    if (!CCFileUtils::sharedFileUtils()->isFileExist(originPath))
    {
        CCLog("%s", ("File:" + originPath + " don't exist!").c_str());

        return false;
    }

    unsigned long len = 0;
    unsigned char *data = CCFileUtils::sharedFileUtils()->getFileData(originPath.c_str(), "rb", &len);

    //检查是否打开成功
    if (!data)
    {
        CCLog("%s", ("Get data from:" + originPath + " error!").c_str());

        return false;
    }

    //由于新文件的路径可能存在未创建的文件夹，所以需要便利创建文件夹才行
    int pos = newPath.find_last_of("\\/");
    int size = newPath.size();
    if (pos < 0 || pos >= size)
    {
        CCLog("%s", ("New path:" + originPath + " error!").c_str());

        return false;
    }

    //生成路径文件夹
    string path = newPath.substr(0, pos);
    if (!createFolderRecursively(path))
    {
        CCLog("%s", ("Can't create folder:" + path).c_str());

        return false;
    }
    
    FILE *file = fopen(newPath.c_str(), "wb");
    //检查是否打开成功
    if (!file)
    {
        newPath = CCFileUtils::sharedFileUtils()->fullPathForFilename(newPath.c_str());
        CCLog("%s", ("Can't open file:" + newPath).c_str());

        return false;
    }

    fwrite(data, sizeof(char), len, file);
    fclose(file);

    return true;
}


bool FileManager::reName(std::string originPath, std::string newPath)
{
    originPath = convertPath(originPath);
    newPath = convertPath(newPath);

    //获取文件名
    int pos = newPath.find_last_of("/\\");
    string newName = newPath.substr(pos + 1);
    //先删除原来的文件
    deleteFile(newPath);

    if (!system(("rename " + originPath + " " + newName).c_str()))
    {
        return true;
    }
    else
    {
        return false;
    }
}


bool FileManager::createFolder(std::string path)
{
    path = convertPath(path);

#if (CC_TARGET_PLATFORM != CC_PLATFORM_WIN32)
    mode_t processMask = umask(0);
    int ret = mkdir(path.c_str(), S_IRWXU | S_IRWXG | S_IRWXO);
    umask(processMask);
    if (ret != 0 && errno != EEXIST)
    {
        return false;
    }
    else
    {
        return true;
    }
#else
    BOOL ret = CreateDirectoryA(path.c_str(), NULL);
    if (!ret && ERROR_ALREADY_EXISTS != GetLastError())
    {
        return false;
    }
    else
    {
        return true;
    }
#endif
}


bool FileManager::createFolderRecursively(std::string path)
{
    path = convertPath(path);

    int pos = 0;
    int size = path.size();
    bool flag = true;
    while (flag)
    {
        pos++;
        pos = path.find_first_of("\\/", pos);
        //如果返回值为1，或者已经是完整路径了，则不需要创建
        if (pos < 0 || pos >= size)
        {
            flag = createFolder(path.substr(0, pos));
            break;
        }
        flag = createFolder(path.substr(0, pos));

//在win32操作系统中强制
#if (CC_TARGET_PLATFORM == CC_PLATFORM_WIN32)
        flag = true;
#endif
    }

    return flag;
}


void FileManager::deleteFolder(std::string path)
{
    path = convertPath(path);

    // Remove downloaded files
#if (CC_TARGET_PLATFORM != CC_PLATFORM_WIN32)
    string command = "rm -r ";
    // Path may include space.
    command += "\"" + path + "\"";
    system(command.c_str());
#else
    string command = "rd /s /q ";
    // Path may include space.
    command += "\"" + path + "\"";
    system(command.c_str());
#endif
}

bool FileManager::deleteFile(std::string path)
{
    path = convertPath(path);

    if (remove(path.c_str()) != 0)
    {
        return true;
    }
    else
    {
        return false;
    }
}

