/** ����Java��PhoneIMEI�Ľӿ�
*/


#ifndef _FILE_MANAGER_H_
#define _FILE_MANAGER_H_


#include <string>


/** �����࣬���û�ȡ�ֻ�IMEI��Ϣ�Ľӿ�
*/
class FileManager
{
public:
    /** ���캯��
    */
    FileManager();
    /** ��������
    */
    virtual ~FileManager();

    /** ��ȡ����
    */
    static FileManager *getInstance();
    /** 
    *	ɾ������
    */
    static void destroyInstance();

    /** 
    *	ת��·�������ݲ�ͬƽ̨����ת��
    */
    std::string convertPath(std::string path, int pos = 0);

    /** �����ļ�
        �������ڸ����ļ���
    */
    bool copyFile(std::string originPath, std::string newPath);

    /** 
    *	������
    *   ������и������ļ������ļ����ᱻɾ��
    */
    bool reName(std::string originPath, std::string newPath);

    /** �½��ļ���
        ����м�·�������������ɴ���ʧ��
    */
    bool createFolder(std::string path);

    /** �ݹ�Ľ����ļ���
        Ҳ�������·���е��ļ��в����ڣ�����Զ��Զ����ɣ�֪������Ŀ¼
    */
    bool createFolderRecursively(std::string path);

    /** ɾ���ļ���
    */
    void deleteFolder(std::string path);
    /** 
    *	ɾ���ļ�
    */
    bool deleteFile(std::string path);

protected:
    static FileManager *m_instance;
};


//_FILE_MANAGER_H
#endif