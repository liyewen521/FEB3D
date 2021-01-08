#ifndef FRMMAIN_H
#define FRMMAIN_H

#include <QDialog>
#include <QMainWindow>
#include <QFileDialog>
#include <QInputDialog>
#include <QMessageBox>
#include <QProgressDialog>
#include <QObject>
#include <QThread>
#include <QTextEdit>
#include <QProgressBar>
#include <QTime>
#include <iostream>
#include <vector>
#include <String>
#include "tiffio.h"  //��tiff�ļ���Ҫ�Ŀ��ļ�
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <cstring>
#include <Qthread>

using namespace std;

#define DRAW_LINE "--------------------------------------------------------------------------------------------"
#define PER_COMPRESS_PROBAR_TIME 7
#define PER_DECOMPRESS_PROBAR_TIME 50
 
// -------------------------ͼ�ν���--------------------------- //
namespace Ui {
class frmMain;
}

class frmMain : public QDialog
{
    Q_OBJECT

public:
    explicit frmMain(QWidget *parent = 0);
    ~frmMain();
	

protected:
    bool eventFilter(QObject *obj, QEvent *event);
    void mouseMoveEvent(QMouseEvent *e);
    void mousePressEvent(QMouseEvent *e);
    void mouseReleaseEvent(QMouseEvent *);

//private slots:
public slots:

    void on_btnMenu_Close_clicked();

    void on_btnMenu_Min_clicked();

    void on_pushButton_2_clicked();

	void on_pushButton_3_clicked();

    void on_pushButton_4_clicked();

    void on_pushButton_5_clicked();

	void on_pushButton_6_clicked();

	void on_pushButton_7_clicked();

	void frmMain::update_progress_bar(int pre_value_1, int min_value_1, int max_value_1, 
									  int pre_value_2, int min_value_2, int max_value_2);

private:

    Ui::frmMain *ui;

    QPoint mousePoint;
    bool mousePressed;
    bool max;
    QRect location;
    QTextEdit lineEdit;
    QTextEdit lineEdit_2;
    QTextEdit lineEdit_3;
    QTextEdit lineEdit_4;
	QTextEdit lineEdit_5;
	QTextEdit lineEdit_6;
	QTextEdit lineEdit_7;
    QTextEdit textEdit;
    QProgressBar progressBar;
    QProgressBar progressBar_2;
    void InitStyle();

};

// ------------------------ͼ��ѹ��---------------------- //

class QThread_Run : public QThread{
	Q_OBJECT
private:

protected:
	void run() Q_DECL_OVERRIDE;
public:

	// ����
	QThread_Run();	// ���캯��
	//~QThread_Run();	// ��������

	bool run_end;	// �ж�ѹ�����߽�ѹ���Ƿ����
	bool compress_or_decompress_flag;	// ������ѹ�����ǽ�ѹ���� 1-->ѹ���� 0-->��ѹ����
	string *file_name_store;	// �洢ͼƬ������ѹ���ļ���
	double total_compress_or_decompress_time;		// ����ѹ�����ѹ����ʱ�䣬����ms��ʱ
	double kernel_compress_or_decompress_time;		// ����FPGA�ں�ʱ�䣬����ms��ʱ
};


#endif // FRMMAIN_H

