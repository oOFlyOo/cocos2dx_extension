/** 调用Java的PhoneIMEI的接口
*/


#ifndef _FILE_MANAGER_H_
#define _FILE_MANAGER_H_


#include <string>


/** 单例类，调用获取手机IMEI信息的接口
*/
class FileManager
{
public:
    /** 构造函数
    */
    FileManager();
    /** 析构函数
    */
    virtual ~FileManager();

    /** 获取单例
    */
    static FileManager *getInstance();
    /** 
    *	删除单例
    */
    static void destroyInstance();

    /** 
    *	转换路径，根据不同平台进行转换
    */
    std::string convertPath(std::string path, int pos = 0);

    /** 复制文件
        不能用于复制文件夹
    */
    bool copyFile(std::string originPath, std::string newPath);

    /** 
    *	重命名
    *   如果已有该名的文件，该文件将会被删除
    */
    bool reName(std::string originPath, std::string newPath);

    /** 新建文件夹
        如果中间路径不存在则会造成创建失败
    */
    bool createFolder(std::string path);

    /** 递归的建立文件夹
        也就是如果路径中的文件夹不存在，则会自动自动生成，知道最终目录
    */
    bool createFolderRecursively(std::string path);

    /** 删除文件夹
    */
    void deleteFolder(std::string path);
    /** 
    *	删除文件
    */
    bool deleteFile(std::string path);

protected:
    static FileManager *m_instance;
};


//_FILE_MANAGER_H
#endif