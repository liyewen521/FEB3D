#include "frmmain.h"
#include "ui_frmmain.h"
#include "iconhelper.h"
#include "myhelper.h"
#include <QTime>
#include <synchapi.h>
#include <ctime>
/* 
 *
 *
 *	B3D OpenCL
 *
 *
 *
 */
#include <cstdlib>
#include <cmath>
#include "CL/opencl.h"
#include "AOCLUtils/aocl_utils.h"
#include <iostream>
#include <vector>
#include <stack>
#include <String>
#include "tiffio.h"
#include "b3d_compression.h"
#include "gzip_tools.h"


using namespace aocl_utils;
using namespace std;

// Tiff image runtime configuration
string input_file_name; 
int total_frame_, image_width_, image_height_, bit_perSample_;
int row_step_, photometric_, sample_format_;
string image_discription_;
vector<tdata_t> image_data_store_;

int detotal_frame_, deimage_width_, deimage_height_, debit_perSample_, derow_step_, dephotometric_, desample_format_;
string deimage_discription_;

scoped_aligned_ptr<cl_ushort> image_data_array;

scoped_aligned_ptr<cl_uchar> image_data_array_output_0;
scoped_aligned_ptr<cl_uchar> image_data_array_output_1;
scoped_aligned_ptr<cl_uchar> image_data_array_output_2;

// OpenCL runtime configuration
const char *kernel_name[] = {"load_data","photon_transform","quanlitization",
	"prediction","rle_coding","gzip"};
cl_platform_id platform = NULL;
scoped_array<cl_device_id> device; 
cl_context context = NULL;
cl_command_queue queue[kernel_number]; 
cl_program program = NULL;
cl_kernel kernel[kernel_number]; 

cl_mem input_buf0, output_buf_0,output_buf_1,output_buf_2;


cl_uint n_device; 
cl_uint Den_device; 
cl_uint num_devices = 0;

cl_float camera_gain;//相机增益
cl_float conversion_error;//转换误差
cl_float quanstep;//量化步长

double kernel_time;	// add by lyw


// Function prototypes
void init_image_data(string original_dir, string *ori_filename, int offset, float cg, float ce, float qu);
bool init_opencl();
void cleanup();
void cl_create_buffer();
void read_image(const char *iTifName);
void convert_vector_to_array(vector<tdata_t> v,cl_ushort* w,int image_height_,int image_width_,int offset);
template <class T> 
void WriteImage(const char *oTifName, T buf);

//must be same as CL file
//---------------/
#define VEC 16 //
//-------------/

//only enable this flag if you want to do separate verification of LZ output before huffman encoding
//will hurt performance and is only meant to be used on the emulator for functional correctness
//must also define this flag on the kernel
//#define DEBUG_LZ_ONLY


//---------------------------------------------------------------------------------------
//  DATA BUFFERS
//---------------------------------------------------------------------------------------

cl_mem input_buf_h;
cl_mem huftable_buf;
cl_mem output_lz_buf;
cl_mem output_huffman_buf;
cl_mem compsize_lz_buf;
cl_mem compsize_huffman_buf;
cl_mem fvp_buf;

//---------------------------------------------------------------------------------------
//  FUNCTION PROTOTYPES
//---------------------------------------------------------------------------------------


void Compress(string compress_dir, string ori_filename);
void DeCompress(string compress_dir, string com_filename, string decompress_dir);

bool deflate_on_FPGA(unsigned char *input, unsigned int *huftable, unsigned int insize, unsigned int outsize, unsigned char marker,
						unsigned int &fvp, unsigned char *output_lz, unsigned short *output_huffman, unsigned int &compsize_lz,
						unsigned int &compsize_huffman);


int inflate_on_host(unsigned char *input, huff_encodenode_t *tree, unsigned int insize, unsigned int outsize, unsigned char marker,
					unsigned int fvp, unsigned short *output_huffman, unsigned int compsize_lz,
					unsigned int compsize_huffman, unsigned int remaining_bytes,
					string decompress_dir, string com_filename);

//void verify(float *verify_var);

/*
 *
 *
 *	图形界面功能函数	
 *
 *
 *
 */
// 图形界面全局变量

QString ui_camera_gain;
QString ui_conversion_error;
QString ui_quanstep;
QStringList file_path_original;
QString folder_path_compressed;
QStringList file_path_compressed;
QString folder_path_decompressed;
QList<QFileInfo> *fileInfo;
bool cl_buffer_first_create;
double init_time;

// 图形界面功能函数 

frmMain::frmMain(QWidget *parent) :
    QDialog(parent),
    ui(new Ui::frmMain)
{
    ui->setupUi(this);

    myHelper::FormInCenter(this);
    this->InitStyle();
}

frmMain::~frmMain()
{
    delete ui;
}

void frmMain::InitStyle()
{
    //设置窗体标题栏隐藏
    this->setWindowFlags(Qt::FramelessWindowHint | Qt::WindowSystemMenuHint | Qt::WindowMinMaxButtonsHint);
    location = this->geometry();
    max = false;
    mousePressed = false;

    //安装事件监听器,让标题栏识别鼠标双击
    ui->lab_Title->installEventFilter(this);

    IconHelper::Instance()->SetIcon(ui->btnMenu_Close, QChar(0xf00d), 10);
    IconHelper::Instance()->SetIcon(ui->btnMenu_Min, QChar(0xf068), 10);
    IconHelper::Instance()->SetIcon(ui->lab_Ico, QChar(0xf015), 12);
}

bool frmMain::eventFilter(QObject *obj, QEvent *event)
{
    if (event->type() == QEvent::MouseButtonDblClick) {
        return true;
    }
    return QObject::eventFilter(obj, event);
}

void frmMain::mouseMoveEvent(QMouseEvent *e)
{
    if (mousePressed && (e->buttons() && Qt::LeftButton) && !max) {
        this->move(e->globalPos() - mousePoint);
        e->accept();
    }
}

void frmMain::mousePressEvent(QMouseEvent *e)
{
    if (e->button() == Qt::LeftButton) {
        mousePressed = true;
        mousePoint = e->globalPos() - this->pos();
        e->accept();
    }
}

void frmMain::mouseReleaseEvent(QMouseEvent *)
{
    mousePressed = false;
}

//关闭软件
void frmMain::on_btnMenu_Close_clicked()
{
	// Free the resources allocated
	cleanup();
    qApp->exit();
}

//窗口最小化
void frmMain::on_btnMenu_Min_clicked()
{
    this->showMinimized();
}

// ------------------选择原始文件夹---------------- //
void frmMain::on_pushButton_2_clicked()
{
	// 打开文件夹，默认获取目录格式为linux格式，即 /
	file_path_original = QFileDialog::getOpenFileNames(this,tr(QStringLiteral("请选择原始图像文件").toStdString().c_str()),".\\",tr(QStringLiteral("TIFF格式图像(*.tif)").toStdString().c_str()));
	if (file_path_original.empty()==true){	
		ui->lineEdit_4->setText("");
		return ;
	}	

	else{
		for(int i = 0; i < file_path_original.size(); i++)
			ui->lineEdit_4->setText(QDir::toNativeSeparators(file_path_original.at(i)) );
		return ;
	}

}

// ----------------选择压缩文件夹------------------ //
void frmMain::on_pushButton_3_clicked()
{
	// 打开文件夹
	folder_path_compressed = QFileDialog::getExistingDirectory(this, tr(QStringLiteral("请选择存放压缩文件的文件夹").toStdString().c_str()),".\\",QFileDialog::ShowDirsOnly | QFileDialog::DontResolveSymlinks);
		
	// 文本框显示文件路径
	if (folder_path_compressed.isEmpty() == true){
		ui->lineEdit_5->setText("");
		return ;
	}	
	else{
		ui->lineEdit_5->setText(QDir::toNativeSeparators(folder_path_compressed));
		return ;
	}		
}
// ------------------选择压缩文件------------------- //
void frmMain::on_pushButton_7_clicked(){

	// 打开文件夹
	file_path_compressed = QFileDialog::getOpenFileNames(this,tr(QStringLiteral("请选择压缩文件").toStdString().c_str()),".\\",tr(QStringLiteral("B3D压缩文件(*.dat)").toStdString().c_str()));

	if (file_path_compressed.empty() == true){
		ui->lineEdit_7->setText("");
		return ;
	}	
	else{
		for(int i = 0;i < file_path_compressed.size(); i++)
			ui->lineEdit_7->setText(QDir::toNativeSeparators(file_path_compressed.at(i)));
	}

}

// -----------------选择解压缩文件夹---------------- //
void frmMain::on_pushButton_6_clicked()
{
	// 打开文件夹
    folder_path_decompressed = QFileDialog::getExistingDirectory(this, tr(QStringLiteral("请选择存放解压缩图像的文件夹").toStdString().c_str()),".\\",QFileDialog::ShowDirsOnly | QFileDialog::DontResolveSymlinks);
	
	// 文本框显示文件路径
	if (folder_path_decompressed.isEmpty() == true){
		ui->lineEdit_6->setText("");
		return ;
	}	
	else
		ui->lineEdit_6->setText(QDir::toNativeSeparators(folder_path_decompressed));

}


// ---------------------------开始压缩--------------------------- //
void frmMain::on_pushButton_4_clicked()
{
	// ------------------判断文件或者文件夹是否正常----------------- //
	if (file_path_original.empty() == true){
		ui->textEdit->setText(DRAW_LINE);
		ui->textEdit->append(QStringLiteral("请输入正确的原始文件。"));
		return ;
	}
	if (folder_path_compressed.isEmpty() == true){	  // 表示文件压缩和文件夹压缩均未选择
		ui->textEdit->setText(DRAW_LINE);
		ui->textEdit->append(QStringLiteral("请输入正确的压缩文件夹。"));
		return ;
	}

	// ------------------先删除文件夹下所有的文件------------------ //
	// 还没写

	// --------------------创建图像压缩的进程----------------------- //
    QThread_Run Pro_Run_1;
	Pro_Run_1.run_end = 0;
	Pro_Run_1.compress_or_decompress_flag = 1;
	Pro_Run_1.total_compress_or_decompress_time = 0.0;
	Pro_Run_1.kernel_compress_or_decompress_time = 0.0;

	// ----------------压缩参数和压缩文件获取---------------- //

    // 获取三个文本框的输入
	ui_camera_gain = ui->lineEdit->text();
    ui_conversion_error = ui->lineEdit_2->text();
    ui_quanstep = ui->lineEdit_3->text();

	// 将三个参数显示出来
	ui->textEdit->setText(DRAW_LINE);
	ui->textEdit->append(QStringLiteral("参数显示： "));
    ui->textEdit->append(QStringLiteral("相机增益： ") + ui_camera_gain);
    ui->textEdit->append(QStringLiteral("转换误差： ") + ui_conversion_error);
    ui->textEdit->append(QStringLiteral("量化步长： ") + ui_quanstep);


	// 读取其中tif文件的个数并显示
	if (file_path_original.size() % PIC_NUM != 0 || ( file_path_original.size() / PIC_NUM < 1 && file_path_original.size() % PIC_NUM == 0)){
		ui->textEdit->append(DRAW_LINE);
		ui->textEdit->append(QStringLiteral("图像文件的数量不能被 ") + QString::number(PIC_NUM)+ QStringLiteral(" 整除或者少于 ")+ QString::number(PIC_NUM)+ QStringLiteral("， 请重新输入 。"));
		return ;
	}
	else
	{
		ui->textEdit->append(DRAW_LINE);
		ui->textEdit->append(QStringLiteral("已选择的图像文件数量为：") + QString::number(file_path_original.size()) + QStringLiteral(" 。"));
		ui->textEdit->append(QStringLiteral("图像文件名为："));
		for(int i = 0;i < file_path_original.size();i ++){
			ui->textEdit->append(file_path_original.at(i).section("/",-1));
		}
		ui->textEdit->moveCursor(QTextCursor::End);	// 把进度条拉到最底部

		
		// 将所有的文件名复制进待处理数组
		Pro_Run_1.file_name_store = new string[file_path_original.size()]();
		for(int i = 0;i < file_path_original.size(); i++)
			Pro_Run_1.file_name_store[i] = (file_path_original.at(i).section("/",-1)).toStdString();

	}

	// ------------------开始逐张的执行图像压缩，100 --> 1 ------------------ //

	// 进程启动
    Pro_Run_1.start();

	// 进度条刷新
	// 生成[b,a]范围内的数值，包括b和a
	// unsigned int range = a - b + 1;
	// unsigned int crand = rand() % range + b;
	srand(time(0));
	for(int i = 0;i <= file_path_original.size(); i++){
		update_progress_bar(rand()%91 + 5, 0, 100, i, 0, file_path_original.size());
        QApplication::processEvents();
		Sleep(PER_COMPRESS_PROBAR_TIME);
		if (i == file_path_original.size() - 2 ) break; 
    }

	// 显示生成的文件名
	ui->textEdit->append(DRAW_LINE);
	ui->textEdit->append(QStringLiteral("生成的压缩文件为："));
	for(int i = 0; i < file_path_original.size()/PIC_NUM; i++)
		ui->textEdit->append(file_path_original.at(i * PIC_NUM).section("/",-1) + QString::fromStdString(".dat"));
	ui->textEdit->append(QStringLiteral("正在校验生成文件"));

	// 等待任务完成
	while(! Pro_Run_1.run_end == 1)
		QApplication::processEvents();
    Pro_Run_1.terminate();
	update_progress_bar(100, 0, 100, file_path_original.size(), 0, file_path_original.size());
	
	// 显示压缩时间
	ui->textEdit->append(DRAW_LINE);
	ui->textEdit->append(QStringLiteral("压缩完成 !"));
	ui->textEdit->append(QStringLiteral("总压缩时间：") + QString::number(Pro_Run_1.total_compress_or_decompress_time) + QStringLiteral(" 毫秒 。"));
	ui->textEdit->append(QStringLiteral("内核执行时间： ") + QString::number(Pro_Run_1.kernel_compress_or_decompress_time) + QStringLiteral(" 毫秒 。"));
	ui->textEdit->append(QStringLiteral("OpenCL初始化时间： ") + QString::number(init_time) + QStringLiteral(" 毫秒 。"));
	ui->textEdit->moveCursor(QTextCursor::End);
}

// ---------------------------开始解压缩--------------------------- //
void frmMain::on_pushButton_5_clicked()
{	
	// ------------------判断文件或者文件夹是否正常----------------- //
	if (folder_path_decompressed.isEmpty() == true){
		ui->textEdit->setText(DRAW_LINE);
		ui->textEdit->append(QStringLiteral("请输入正确的解压缩文件夹。"));
		return ;
	}
	if (file_path_compressed.empty() == true){
		ui->textEdit->setText(DRAW_LINE);
		ui->textEdit->append(QStringLiteral("请输入正确的压缩文件。"));
		return ;
	}

	// --------------------创建图像解压缩的进程------------------- //
    QThread_Run Pro_Run_0;
	Pro_Run_0.run_end = 0;
	Pro_Run_0.compress_or_decompress_flag = 0;


	// ----------------解压缩文件获取---------------- //

	// 显示文件名
	ui->textEdit->setText(DRAW_LINE);
	ui->textEdit->append(QStringLiteral("已选择的文件数量为：") + QString::number(file_path_compressed.size()) + QStringLiteral(" 。"));
	ui->textEdit->append(QStringLiteral("压缩文件名为："));
	for(int i = 0;i < file_path_compressed.size();i ++){
		ui->textEdit->append(file_path_compressed.at(i).section("/",-1));
	}
	ui->textEdit->moveCursor(QTextCursor::End);	// 把进度条拉到最底部
	if (file_path_compressed.size() == 0) return ;
		
	// 将所有的文件名复制进待处理数组
	Pro_Run_0.file_name_store = new string[file_path_compressed.size()]();
	for(int i = 0;i < file_path_compressed.size(); i++)
		Pro_Run_0.file_name_store[i] = (file_path_compressed.at(i).section("/",-1)).toStdString();

	// ------------------开始执行图像解压缩，1-->100 ------------------ //
	
	// 启动图像压缩的进程
	Pro_Run_0.start();

	// 进度条刷新
	srand(time(0));
	for(int i = 0;i <= file_path_compressed.size() * PIC_NUM; i++){
		update_progress_bar(rand()%91 + 5, 0, 100, i, 0, file_path_compressed.size() * PIC_NUM);
		QApplication::processEvents();
		Sleep(PER_DECOMPRESS_PROBAR_TIME);
		if (i == file_path_compressed.size() * PIC_NUM - 1 ) break; 
	}

	// 显示生成图像名
	ui->textEdit->append(DRAW_LINE);
	ui->textEdit->append(QStringLiteral("生成的解压缩图像为："));
	for(int i = 0; i < file_path_compressed.size() * PIC_NUM; i++)
		ui->textEdit->append(file_path_compressed.at(i/PIC_NUM).section("/",-1) + QString::fromStdString("_") + QString::number(i%PIC_NUM) + QString::fromStdString(".tif"));
	ui->textEdit->append(QStringLiteral("正在校验生成图像"));

	// 等待任务完成
	while(! Pro_Run_0.run_end == 1)
		QApplication::processEvents();
	Pro_Run_0.terminate();
	update_progress_bar(100, 0, 100, file_path_compressed.size() * PIC_NUM, 0, file_path_compressed.size() * PIC_NUM);
	
	
	// 显示压缩时间
	ui->textEdit->append(DRAW_LINE);
	ui->textEdit->append(QStringLiteral("解压缩完成 !"));
	ui->textEdit->append(QStringLiteral("总解压缩时间：") + QString::number(Pro_Run_0.total_compress_or_decompress_time) + QStringLiteral("毫秒 。"));
	ui->textEdit->moveCursor(QTextCursor::End);
}

// ---------------------------进度条更新函数--------------------------- //
void frmMain::update_progress_bar(int pre_value_1, int min_value_1, int max_value_1, 
								  int pre_value_2, int min_value_2, int max_value_2)
								  // 参数分别为:
								  // 分进度条当前值，最小值，最大值
								  // 总进度条当前值，最小值，最大值
								  // 例子 ：update_progress_bar(100, 0, 100, 1, 0, 5); 分进度条显示100%进度，总进度条显示20%进度
{
    // 分进度条刷新
    ui->progressBar->setOrientation(Qt::Horizontal);	// 水平方向
	ui->progressBar->setMinimum(min_value_1);	// 最小值
	ui->progressBar->setMaximum(max_value_1);	// 最大值
    ui->progressBar->setValue(pre_value_1);		// 当前进度

    // 总进度条刷新
    ui->progressBar_2->setOrientation(Qt::Horizontal);	// 水平方向
	ui->progressBar_2->setMinimum(min_value_2);		// 最小值
	ui->progressBar_2->setMaximum(max_value_2);		// 最大值
    ui->progressBar_2->setValue(pre_value_2);		// 当前进度
}


// --------------------------------- 多线程需要的函数，用于执行压缩和解压缩函数 -------------------------------- //
// 构造函数
QThread_Run::QThread_Run(){
	
}
//QThread_Run::~QThread_Run(){
//	
//}
// run函数
void QThread_Run::run(){
	
	clock_t start_time = clock();
	if(compress_or_decompress_flag == 1){

		//--------------------- 压缩 ---------------------//
		for(int i = 0; i < file_path_original.size()/PIC_NUM; i++){

			// Initialize the image data.
			init_image_data(file_path_original.at(0).section("/", 0, -2).toStdString(), file_name_store, i, 
							ui_camera_gain.toFloat(), ui_camera_gain.toFloat(), ui_quanstep.toFloat());
			// total_compress_or_decompress_time = 1000 *(clock() - start_time) / (double)CLOCKS_PER_SEC;
			// Initialize OpenCL 写在main函数
			
			// 建立buffer
			if(cl_buffer_first_create == 1){
				cl_create_buffer();
				cl_buffer_first_create = 0;
			} 

			// Run the kernel.
			Compress(folder_path_compressed.toStdString(), file_name_store[0 + PIC_NUM*i]);

			// cleanup函数写在退出按钮上面

			kernel_compress_or_decompress_time = kernel_time + kernel_compress_or_decompress_time;
		}
	}
	else
	{
		//--------------------- 解压缩 ---------------------//
		for(int i = 0; i < file_path_compressed.size(); i++)
			DeCompress(file_path_compressed.at(0).section("/", 0, -2).toStdString(), file_name_store[i], folder_path_decompressed.toStdString());
		
	}
	
	run_end = 1;
	total_compress_or_decompress_time = 1000 *(clock() - start_time) / (double)CLOCKS_PER_SEC;

}


/* 
 *
 *
 *	B3D Function Implementation
 *
 *
 *
 */
void cl_create_buffer(){

	cl_int status;

	// Input buffers.
	input_buf0 = clCreateBuffer(context, CL_MEM_READ_ONLY, 
		n_device * PIC_NUM * sizeof(cl_ushort), NULL, &status);
	checkError(status, "Failed to create buffer\n");

	// Output buffer.
	output_buf_0 = clCreateBuffer(context, CL_MEM_WRITE_ONLY, 
		n_device * PIC_NUM * sizeof(cl_ushort), NULL, &status);
	checkError(status, "Failed to create buffer\n");

	output_buf_1 = clCreateBuffer(context, CL_MEM_WRITE_ONLY, 
		n_device * PIC_NUM * sizeof(cl_char), NULL, &status);
	checkError(status, "Failed to create buffer\n");

	output_buf_2 = clCreateBuffer(context, CL_MEM_WRITE_ONLY, 
		sizeof(cl_uint), NULL, &status);
	checkError(status, "Failed to create buffer\n");

	// Input buffers
	input_buf_h = clCreateBuffer(context, CL_MEM_READ_ONLY, n_device * PIC_NUM * 3 * sizeof(cl_char), NULL, &status);
	checkError(status, "Failed to create buffer for input");

	huftable_buf = clCreateBuffer(context, CL_MEM_READ_WRITE, 1024, NULL, NULL);
	checkError(status, "Failed to create buffer for huftable");

	fvp_buf = clCreateBuffer(context, CL_MEM_WRITE_ONLY, sizeof(int), NULL, &status);
	checkError(status, "Failed to create buffer for fvp");

	// Output buffers
	output_huffman_buf = clCreateBuffer(context, CL_MEM_WRITE_ONLY, n_device * PIC_NUM * 6 * sizeof(cl_char) * sizeof(char), NULL, &status);
	checkError(status, "Failed to create buffer for output_huffman");

	compsize_lz_buf = clCreateBuffer(context, CL_MEM_WRITE_ONLY, sizeof(int), NULL, &status);
	checkError(status, "Failed to create buffer for compsize_lz");

	compsize_huffman_buf = clCreateBuffer(context, CL_MEM_WRITE_ONLY, sizeof(int), NULL, &status);
	checkError(status, "Failed to create buffer for compsize_lz");
}


cl_int status;
void Compress(string compress_dir, string ori_filename)
{
	//	// Input buffers.
	//input_buf0 = clCreateBuffer(context, CL_MEM_READ_ONLY, 
	//	n_device * PIC_NUM * sizeof(cl_ushort), NULL, &status);
	//checkError(status, "Failed to create buffer\n");


	//// Output buffer.

	//output_buf_0 = clCreateBuffer(context, CL_MEM_WRITE_ONLY, 
	//	n_device * PIC_NUM * sizeof(cl_ushort), NULL, &status);
	//checkError(status, "Failed to create buffer\n");

	//output_buf_1 = clCreateBuffer(context, CL_MEM_WRITE_ONLY, 
	//	n_device * PIC_NUM * sizeof(cl_char), NULL, &status);
	//checkError(status, "Failed to create buffer\n");

	//output_buf_2 = clCreateBuffer(context, CL_MEM_WRITE_ONLY, 
	//	sizeof(cl_uint), NULL, &status);
	//checkError(status, "Failed to create buffer\n");

	
	//string com = input_file_name + ".dat";//输出文件名
	string com = compress_dir+ "//" + ori_filename + ".dat";	// 压缩文件的路径和文件名
	FILE *fpw;
	if ((fpw = fopen(com.c_str(), "wb")) == NULL)	//打开或者新建读取.dat文件操作不成功 
	{
		cout << "Error: Failed to Open File" << endl;
		exit(1);//结束程序的执行
	}
	
	
	fwrite(&bit_perSample_, sizeof(int), 1, fpw);

	fwrite(&total_frame_, sizeof(int), 1, fpw);

	const double t1 = getCurrentTimestamp();
	// Transfer inputs to each device.
	status = clEnqueueWriteBuffer(queue[0], input_buf0, CL_TRUE,
		0, n_device * PIC_NUM * sizeof(cl_ushort), image_data_array, 0, NULL,NULL);//将host内存里面的数传入FPGA
	checkError(status, "Failed to transfer input data");


	// Kernel Load Data
	unsigned argi = 0;
	unsigned kernel_index = 0;
		
	status = clSetKernelArg(kernel[kernel_index], argi++, sizeof(cl_mem), &input_buf0);
	checkError(status, "Failed to set argument %d", argi - 1);
	// 
	status = clEnqueueTask(queue[kernel_index], kernel[kernel_index],0,NULL,NULL);
	checkError(status, "Failed to launch kernel %d",kernel_index);



	// Kernel Photon Transform
	argi = 0;
	kernel_index++;
	
	status = clSetKernelArg(kernel[kernel_index], argi++, sizeof(cl_float), &camera_gain);
	checkError(status, "Failed to set argument %d", argi - 1);
	status = clSetKernelArg(kernel[kernel_index], argi++, sizeof(cl_float), &conversion_error);
	checkError(status, "Failed to set argument %d", argi - 1);
	//
	status = clEnqueueTask(queue[kernel_index], kernel[kernel_index],0, NULL,NULL);
	checkError(status, "Failed to launch kernel %d",kernel_index);


	// Kernel Quanlitization
	argi = 0;
	kernel_index++;
		
	status = clSetKernelArg(kernel[kernel_index], argi++, sizeof(cl_float), &quanstep);
	checkError(status, "Failed to set argument %d", argi - 1);
	////
	status = clEnqueueTask(queue[kernel_index], kernel[kernel_index],0, NULL,NULL);
	checkError(status, "Failed to launch kernel %d",kernel_index);


	// Kernel Prediction  
	argi = 0;
	kernel_index++;

	//
	status = clEnqueueTask(queue[kernel_index], kernel[kernel_index],0, NULL,NULL);
	checkError(status, "Failed to launch kernel %d",kernel_index);



	// Kernel RLE Coding
	argi = 0;
	kernel_index++;

	status = clSetKernelArg(kernel[kernel_index], argi++, sizeof(cl_mem), &output_buf_0);
	checkError(status, "Failed to set argument %d", argi - 1);

	status = clSetKernelArg(kernel[kernel_index], argi++, sizeof(cl_mem), &output_buf_1);
	checkError(status, "Failed to set argument %d", argi - 1);
	status = clSetKernelArg(kernel[kernel_index], argi++, sizeof(cl_mem), &output_buf_2);
	checkError(status, "Failed to set argument %d", argi - 1);
			
	status = clEnqueueTask(queue[kernel_index], kernel[kernel_index],0, NULL,NULL);
	checkError(status, "Failed to launch kernel %d",kernel_index);

	
	clFinish(queue[kernel_index]);
	

	// Read the result. This the final operation.
	cl_event read_event[2];
	cl_uint num = 0;
	status = clEnqueueReadBuffer(queue[kernel_index], output_buf_2, CL_TRUE,
		0, sizeof(cl_uint), &num,0,NULL,NULL);
	//printf("RunlengthSize: %d\n",3*num);  

	image_data_array_output_0.reset(2*num);
	status = clEnqueueReadBuffer(queue[kernel_index], output_buf_0, CL_FALSE,
		0, num * sizeof(cl_ushort), image_data_array_output_0,0,NULL,&read_event[0]);

	image_data_array_output_1.reset(num);
	status = clEnqueueReadBuffer(queue[kernel_index], output_buf_1, CL_FALSE,
		0, num * sizeof(cl_char), image_data_array_output_1,0,NULL,&read_event[1]);

	

	clWaitForEvents(2,read_event);
	//printf("RunlengthData: %d\n", image_data_array_output_0[0]);  
	
	image_data_array_output_2.reset(3*num);
	for(int i = 0; i < 2*num; i++)
	{
		image_data_array_output_2[i] = image_data_array_output_0[i];
	}
	for(int i = 0; i < num; i++)
	{
		image_data_array_output_2[2*num+i] = image_data_array_output_1[i];
	}
	num = 3*num;


	/*if(input_buf0) {
	  clReleaseMemObject(input_buf0);
	}
  
	if(output_buf_0) {
		clReleaseMemObject(output_buf_0);
	}
	if(output_buf_1) {
		clReleaseMemObject(output_buf_1);
	}
	if(output_buf_2) {
		clReleaseMemObject(output_buf_2);
	}*/

	//image_data_array.release();
	//image_data_array_output_0.release();
	//image_data_array_output_1.release();
	//image_data_array_output_2.release();
	//------------------------------------------------------------------
	// 1- Create huffman tree and select marker on host
	//------------------------------------------------------------------
		

	//Flow control variable
	bool error = false;
	//Kernel Variables
	unsigned int insize, outsize;
	unsigned char marker;
	unsigned int compsize_lz = 0;
	unsigned int compsize_huffman = 0;
	unsigned int fvp = 0;


	insize = num;
	// Worst case output_lz buffer size (too pessimistic for now)
	outsize = insize*2;
	
	//---------------------------
	//  Buffers
	//--\/-\/-\/-\/-\/-\/-\/
	scoped_aligned_ptr<cl_uchar> output_lz;
	output_lz.reset(outsize);
	scoped_aligned_ptr<cl_ushort> output_huffman;
	output_huffman.reset(outsize);
	
	/*unsigned char *output_lz = (unsigned char *)alignedMalloc(outsize);
	unsigned short *output_huffman = (unsigned short *)alignedMalloc(outsize);*/

	if (!image_data_array_output_2 || !output_lz || !output_huffman) {
		printf("Can't allocate memory for output\n");
		return;
	}

	//here truncate the file so that the
	//number of chars is a multiple of VEC
	int remaining_bytes = insize % (2*VEC);
	insize -= remaining_bytes;
	//insize += (2*VEC - remaining_bytes);
	//-----------------------------------------------
	// Host portion of HUFFMAN compression
	//-----------------------------------------------

	huff_sym_t       sym[256], tmp;
	huff_bitstream_t stream;
	unsigned int k, compsize_huffman_host, swaps, symbol;

	// Calculate and sort histogram for input data 统计频数，并找最小值 
	marker = _Huffman_Hist( image_data_array_output_2, sym, insize );

	//inject marker into histogram to improve its encoding
	//set marker count to half the file size

	sym[marker].Count = insize/3;
	fwrite(sym, sizeof(huff_sym_t), 256, fpw);
	huff_encodenode_t nodes[MAX_TREE_NODES];
	// Initialize all leaf nodes
	int num_symbols = 0;
	for( k = 0; k < 256; k++ )
	{
		if( sym[k].Count > 0 )
		{
			nodes[num_symbols].Symbol = sym[k].Symbol;
			nodes[num_symbols].Count = sym[k].Count;
			nodes[num_symbols].Level = 0;
			nodes[num_symbols].ChildA = (huff_encodenode_t *) 0;
			nodes[num_symbols].ChildB = (huff_encodenode_t *) 0;
			num_symbols++;
		}
	}
	
	// Build Huffman tree
	huff_encodenode_t *tree = _Huffman_MakeTree( sym, nodes, num_symbols );
	//create huffman table to send to kernel
	unsigned int *huftable = (unsigned int *)alignedMalloc(1024);

	if (!huftable) {
		printf("Can't allocate memory for huftable\n");
		error = true;
	} else {
		for (k = 0; k < 256; k++)
		{
			huftable[k] = (sym[k].Bits << 16) | sym[k].Code;
			if (sym[k].Bits > 16)
			{
				printf ("CANNOT CREATE A HUFFMAN TREE, SOMETHING IS WRONG!!!\n");
				printf ("Exiting...\n");
				error = true;
				break;
			}
		}
	}
	if (!error) {
		
		//------------------------------------------------------------------
		// 2- Deflate input file on *FPGA*
		//------------------------------------------------------------------
		//printf("insize = %d", insize);
		bool C_istrue = deflate_on_FPGA(image_data_array_output_2, huftable, insize, outsize, marker, fvp, output_lz,
										 			output_huffman, compsize_lz, compsize_huffman);
		const double t2 = getCurrentTimestamp();
		//printf("\nTime: %0.3f ms\n", (t2 - t1) * 1e3);
		kernel_time = (t2 - t1) * 1e3;
		//printf("compsize_huffman: %d\n",compsize_huffman);
		
		/*********************写数据*********************/


		int discri_len = strlen(image_discription_.c_str());
		unsigned int  rows = image_height_;
		unsigned int cols = image_width_;

		fwrite(&camera_gain, sizeof(float), 1, fpw);
		fwrite(&conversion_error, sizeof(float), 1, fpw);
		fwrite(&quanstep, sizeof(float), 1, fpw);

		fwrite(&row_step_, sizeof(int), 1, fpw);
		fwrite(&photometric_, sizeof(int), 1, fpw);
		fwrite(&sample_format_, sizeof(int), 1, fpw);
		fwrite(&discri_len, sizeof(int), 1, fpw);
		fwrite(image_discription_.c_str(), sizeof(char), discri_len, fpw);
		fwrite(&rows, sizeof(unsigned int), 1, fpw);
		fwrite(&cols, sizeof(unsigned int), 1, fpw);
	
		fwrite(&insize, sizeof(unsigned int), 1, fpw);
		fwrite(&outsize, sizeof(unsigned int), 1, fpw);
		fwrite(&marker, sizeof(unsigned char), 1, fpw);
		fwrite(&fvp, sizeof(unsigned int), 1, fpw);
		fwrite(&compsize_huffman, sizeof(unsigned int), 1, fpw);//printf("%d\n", compsize_huffman);
		fwrite(output_huffman, 2, compsize_huffman/2+1, fpw);   
		fwrite(&compsize_lz, sizeof(unsigned int), 1, fpw);
		fwrite(&remaining_bytes, sizeof(int), 1, fpw);

		//printf("insize_fpga = %d\n", insize);
		scoped_aligned_ptr<cl_uchar> other_bytes;
		other_bytes.reset(VEC - fvp + remaining_bytes);
		int nn = 0;
		for(int i = fvp; i < VEC; i++)
		{
			other_bytes[nn] = image_data_array_output_2[insize - VEC + i];
			nn++;
		}
		for(int i = 0; i < remaining_bytes; i++)
		{
			other_bytes[nn] = image_data_array_output_2[insize++];
			nn++;
		}
	
		fwrite(other_bytes, 1, VEC - fvp + remaining_bytes, fpw);

		unsigned int picture_number = PIC_NUM;
		fwrite(&picture_number, sizeof(unsigned int), 1, fpw);

		fclose(fpw);

		if(C_istrue == true)
		{
			printf("Compress Succeed!\n");
		}
		else
		{
			printf("Compress Failed!\n");
			exit(1);
		}
		other_bytes.release();
	}
	
	

	//free buffers

	if (huftable) {
		alignedFree(huftable);
	}

	output_lz.release();
	output_huffman.release();
	
}

void DeCompress(string compress_dir, string com_filename, string decompress_dir)
{

	// Sets the current working directory to the same directory that contains
	if(!setCwdToExeDir()) { 
		exit(1);		 
	}

	//// 获取 相机增益，转换误差，量化步长
	//camera_gain = (float)(30000.0 / 65535.0);
	//conversion_error = (float)1.6;
	//quanstep = 2.0; //奇偶 

	//---------------------------------------------------------------------------
	// 3- Inflate FPGA output on host and compare to input for verification
	//---------------------------------------------------------------------------
	/*********************读数据*********************/
	//string com = "123.tif.dat";	//压缩文件名
	//string com = input_file_name + ".dat";	//压缩文件名

	string com = compress_dir + "//" + com_filename;	//压缩文件名
	FILE *fpr;
	if ((fpr = fopen(com.c_str(), "rb")) == NULL)//打开操作不成功
	{
		cout << "Error: Failed to Open Compress File" << endl;
		exit(1);//结束程序的执行
	}
	fread(&debit_perSample_, sizeof(int), 1, fpr);

	fread(&detotal_frame_, sizeof(int), 1, fpr);

	huff_sym_t desym[256];
	fread(desym, sizeof(huff_sym_t), 256, fpr);
	
	int dediscri_len;
	unsigned int  derows;
	unsigned int decols;

	fread(&camera_gain, sizeof(float), 1, fpr);
	fread(&conversion_error, sizeof(float), 1, fpr);
	fread(&quanstep, sizeof(float), 1, fpr);

	fread(&derow_step_, sizeof(int), 1, fpr);
	fread(&dephotometric_, sizeof(int), 1, fpr);
	fread(&desample_format_, sizeof(int), 1, fpr);
	fread(&dediscri_len, sizeof(int), 1, fpr);

	char *dedes = new char[dediscri_len];
	fread(dedes, sizeof(char), dediscri_len, fpr);
	deimage_discription_ = dedes;


	fread(&derows, sizeof(unsigned int), 1, fpr);
	fread(&decols, sizeof(unsigned int), 1, fpr);

	deimage_height_ = derows;
	deimage_width_ = decols;
	Den_device = deimage_height_ * deimage_width_;

	unsigned int deinsize = 0;
	unsigned int deoutsize = 0;
	unsigned char demarker = 0;
	unsigned int defvp = 0;
	unsigned int decompsize_lz = 0;
    unsigned int decompsize_huffman = 0;
	int deremaining_bytes = 0;
		
	fread(&deinsize, sizeof(unsigned int), 1, fpr);
	fread(&deoutsize, sizeof(unsigned int), 1, fpr);
	fread(&demarker, sizeof(unsigned char), 1, fpr);
	fread(&defvp, sizeof(unsigned int), 1, fpr);
	fread(&decompsize_huffman, sizeof(unsigned int), 1, fpr);
	scoped_aligned_ptr<cl_ushort> deoutput_huffman;
	deoutput_huffman.reset(deoutsize);

	fread(deoutput_huffman, 2, decompsize_huffman/2+1, fpr);   

	fread(&decompsize_lz, sizeof(unsigned int), 1, fpr);
	fread(&deremaining_bytes, sizeof(int), 1, fpr);

	scoped_aligned_ptr<cl_uchar> deother_bytes;
	deother_bytes.reset(VEC - defvp + deremaining_bytes);
	fread(deother_bytes, 1, VEC - defvp + deremaining_bytes, fpr);
	

	fclose(fpr);
		
	huff_encodenode_t denodes[MAX_TREE_NODES];
	// Initialize all leaf nodes
	int denum_symbols = 0;
	for( int k = 0; k < 256; k++ )
	{
		if( desym[k].Count > 0 )
		{
			denodes[denum_symbols].Symbol = desym[k].Symbol;
			denodes[denum_symbols].Count = desym[k].Count;
			denodes[denum_symbols].Level = 0;
			denodes[denum_symbols].ChildA = (huff_encodenode_t *) 0;
			denodes[denum_symbols].ChildB = (huff_encodenode_t *) 0;
			denum_symbols++;
		}
	}										
		
	// reBuild Huffman tree
		
	huff_encodenode_t *detree = _Huffman_MakeTree( desym, denodes, denum_symbols );
	//printf("%d\n", decompsize_huffman);   
	//printf("%d\n", defvp);
	bool DC_Istrue = inflate_on_host(deother_bytes, detree, deinsize, deoutsize, demarker, defvp, deoutput_huffman, decompsize_lz, decompsize_huffman, deremaining_bytes, decompress_dir, com_filename);


	//---------------------------------------------------------------------------
	// 4- Print result and cleanup
	//---------------------------------------------------------------------------

	if( DC_Istrue == true )
	{
		printf("DeCompress Succeed!\n");
	}
		
	else
	{
		printf("DeCompress Failed!\n");
	}
		
	deoutput_huffman.release();
	deother_bytes.release();


	//double throughput = (double)insize / (1024.0 * 1024.0 * double(time_ns_profiler) * 1e-9);

	//printf("Compression Ratio = %.2f%%, ", (float)compsize_huffman/insize*100);

	//printf("Throughput = %.2f MB/s \n", throughput);

}

bool deflate_on_FPGA(unsigned char *input, unsigned int *huftable, unsigned int insize, unsigned int outsize, unsigned char marker,
						unsigned int &fvp, unsigned char *output_lz, unsigned short *output_huffman, unsigned int &compsize_lz,
						unsigned int &compsize_huffman)
{
	
	//// Input buffers
	//input_buf_h = clCreateBuffer(context, CL_MEM_READ_ONLY, insize * sizeof(char), NULL, &status);
	//checkError(status, "Failed to create buffer for input");

	//huftable_buf = clCreateBuffer(context, CL_MEM_READ_WRITE, 1024, NULL, NULL);
	//checkError(status, "Failed to create buffer for huftable");

	//fvp_buf = clCreateBuffer(context, CL_MEM_WRITE_ONLY, sizeof(int), NULL, &status);
	//checkError(status, "Failed to create buffer for fvp");

	//// Output buffers

	//output_huffman_buf = clCreateBuffer(context, CL_MEM_WRITE_ONLY, outsize * sizeof(char), NULL, &status);
	//checkError(status, "Failed to create buffer for output_huffman");

	//compsize_lz_buf = clCreateBuffer(context, CL_MEM_WRITE_ONLY, sizeof(int), NULL, &status);
	//checkError(status, "Failed to create buffer for compsize_lz");

	//compsize_huffman_buf = clCreateBuffer(context, CL_MEM_WRITE_ONLY, sizeof(int), NULL, &status);
	//checkError(status, "Failed to create buffer for compsize_lz");

	// Transfer inputs. Each of the host buffers supplied to
	// clEnqueueWriteBuffer here should be "aligned" to ensure that DMA is used
	// for the host-to-device transfer.
	cl_event write_event[2];
	status = clEnqueueWriteBuffer(queue[5], input_buf_h, CL_FALSE, 0, insize * sizeof(cl_uchar), input, 0, NULL, &write_event[0]);
	checkError(status, "Failed to transfer input");

	clEnqueueWriteBuffer(queue[5], huftable_buf, CL_TRUE, 0, 1024, huftable, 0, NULL, &write_event[1]);
	checkError(status, "Failed to transfer huftable");
	
	//------------------------------------------------------------------
	// 3- [openCL] Set kernel arguments and enqueue commands into kernel
	//------------------------------------------------------------------

	// Set kernel arguments.
	unsigned argi = 0;

	status = clSetKernelArg(kernel[5], argi++, sizeof(cl_mem), &input_buf_h);
	checkError(status, "Failed to set argument %d on kernel 1", argi - 1);
	status = clSetKernelArg(kernel[5], argi++, sizeof(cl_mem), &huftable_buf);
	checkError(status, "Failed to set argument %d on kernel 1", argi - 1);

	status = clSetKernelArg(kernel[5], argi++, sizeof(cl_int), (void *) &insize);
	checkError(status, "Failed to set argument %d on kernel 1", argi - 1);
	status = clSetKernelArg(kernel[5], argi++, sizeof(cl_char), (void *) &marker);
	checkError(status, "Failed to set argument %d on kernel 1", argi - 1);

	status = clSetKernelArg(kernel[5], argi++, sizeof(cl_mem), &fvp_buf);
	checkError(status, "Failed to set argument %d on kernel 1", argi - 1);
	
	status = clSetKernelArg(kernel[5], argi++, sizeof(cl_mem), &output_huffman_buf);
	checkError(status, "Failed to set argument %d on kernel 1", argi - 1);
	status = clSetKernelArg(kernel[5], argi++, sizeof(cl_mem), &compsize_lz_buf);
	checkError(status, "Failed to set argument %d on kernel 1", argi - 1);
	status = clSetKernelArg(kernel[5], argi++, sizeof(cl_mem), &compsize_huffman_buf);
	checkError(status, "Failed to set argument %d on kernel 1", argi - 1);

	// Launch the problem
	cl_event kernel_event;

	
	cl_event finish_event[4];


	// don't forget to adjust the number of events when enqueuing more read buffers -------------|
	checkError(status, "Failed to launch kernel");

	//start measuring before launching kernel
	const double start_time = getCurrentTimestamp();

	// Enqueue kernel.
	// Events are used to ensure that the kernel is not launched until
	// the writes to the input buffers have completed.
	const size_t global_work_size = 1;
	const size_t local_work_size = 1;

	status = clEnqueueTask(queue[5], kernel[5], 2, write_event, &kernel_event);

	checkError(status, "Failed to launch kernel");

	//---------------------------------------------------------------------------
	// 4- [openCL] Dequeue read buffers from kernel and verify results from them
	//---------------------------------------------------------------------------

	// Read the result. This the final operation.
	status = clEnqueueReadBuffer(queue[5], fvp_buf, CL_FALSE, 0, sizeof(int), &fvp, 1, &kernel_event, &finish_event[0]);
	status = clEnqueueReadBuffer(queue[5], output_huffman_buf, CL_FALSE, 0, outsize * sizeof(char), output_huffman, 1, &kernel_event, &finish_event[1]);
	status = clEnqueueReadBuffer(queue[5], compsize_huffman_buf, CL_FALSE, 0, sizeof(int), &compsize_huffman, 1, &kernel_event, &finish_event[2]);
	status = clEnqueueReadBuffer(queue[5], compsize_lz_buf, CL_FALSE, 0, sizeof(int), &compsize_lz, 1, &kernel_event, &finish_event[3]);


	// Release local events.
	clReleaseEvent(write_event[0]);
	clReleaseEvent(write_event[1]);

	// Wait for all devices to finish.

	clWaitForEvents(4, finish_event);
	bool C_ver = true;
	if (!output_huffman) {
		C_ver = false;
	}
	

	/*if(compsize_lz_buf)
		clReleaseMemObject(compsize_lz_buf);
	if(compsize_huffman_buf)
		clReleaseMemObject(compsize_huffman_buf);
	if(fvp_buf)
		clReleaseMemObject(fvp_buf);
	if(huftable_buf)
		clReleaseMemObject(huftable_buf);
	if(output_huffman_buf)
		clReleaseMemObject(output_huffman_buf);
	if(input_buf_h){
		clReleaseMemObject(input_buf_h);
	}*/

	// Release all events
	clReleaseEvent(kernel_event);

	clReleaseEvent(finish_event[0]);
	clReleaseEvent(finish_event[1]);
	clReleaseEvent(finish_event[2]);
	clReleaseEvent(finish_event[3]);
	return C_ver;
}


int inflate_on_host(unsigned char *input, huff_encodenode_t *tree, unsigned int insize, unsigned int outsize, unsigned char marker,
					unsigned int fvp, unsigned short *output_huffman, unsigned int compsize_lz,
					unsigned int compsize_huffman, unsigned int remaining_bytes,
					string decompress_dir, string com_filename)
{

	unsigned char *output_huffman_char = (unsigned char *)alignedMalloc(outsize);
	unsigned char *decompress_lz = (unsigned char *)alignedMalloc(outsize);
	unsigned char *decompress_huff = (unsigned char *)alignedMalloc(outsize);
	unsigned char *decompress_huff_lz = (unsigned char *)alignedMalloc(outsize);
	


	//convert output_huffman from shorts to chars
	for (int i = 0; i < compsize_huffman; i++)
	{
		//transform from shorts to chars
		short comp_short = output_huffman[i/2];
		if(i%2 == 0)
			comp_short >>= 8;
		unsigned char comp_char = comp_short;
		output_huffman_char[i] = comp_char;
	}

	//---------------------------------------
	// DECOMPRESS HUFFMAN
	//---------------------------------------

	Huffman_Uncompress(output_huffman_char, decompress_huff, tree, compsize_huffman, compsize_lz, marker);   



	//append last VEC bytes starting from fvp
	for(int i = 0; i < VEC - fvp; i++)
	{
		decompress_huff[compsize_lz++] = input[i];
		if(input[i] == marker)
			decompress_huff[compsize_lz++] = 0;
	}
	
	unsigned int m = VEC - fvp;
	//append to output_lz the ommitted bytes
	for(int i = VEC - fvp; i < VEC - fvp + remaining_bytes; i++)
	{
		decompress_huff[compsize_lz++] = input[m++];
		if(input[m-1] == marker)
			decompress_huff[compsize_lz++] = 0;
	}						

	insize += remaining_bytes; 

	//---------------------------------------
	// DECOMPRESS LZ
	//---------------------------------------
	
	LZ_Uncompress( decompress_huff, decompress_huff_lz, compsize_lz );

	//---------------------------------------

	unsigned short *decompress_rle_len = (unsigned short *)decompress_huff_lz;
	char *decompress_rle_dat = (char *)decompress_huff_lz;
	
	scoped_aligned_ptr<cl_float> decompress_pre;
	decompress_pre.reset(PIC_NUM*Den_device);
	unsigned int n = 0;

	for(int i = 0; i < insize/3; i++)
	{
		for(int j = 0; j < decompress_rle_len[i]; j++)
		{
			decompress_pre[n] = (float)(decompress_rle_dat[2*insize/3 + i]);
			n++;

		}
	}
	
	scoped_aligned_ptr<cl_float> decompress_qua;
	decompress_qua.reset(PIC_NUM*Den_device);
	
	for(int i = 0; i < PIC_NUM*Den_device; i++)
	{
		if(i == 0)
		{
			decompress_qua[i] = decompress_pre[i];
		 }
		else
		{
			decompress_qua[i] = decompress_pre[i] + decompress_qua[i - 1];
		}
	}


	scoped_aligned_ptr<cl_ushort> decompress_dat;
	decompress_dat.reset(PIC_NUM*Den_device);
	vector<unsigned short* > image_data;
	for(int z = 0; z < PIC_NUM; z++)
	{
		for(int i = 0; i < Den_device; i++)
		{
			decompress_dat[z*Den_device+i] = (unsigned short)((pow(decompress_qua[z*Den_device+i]/2, 2) - conversion_error*conversion_error)/camera_gain);
		}
	}
	
	/*for(int i = (PIC_NUM-1)*Den_device; i < PIC_NUM*Den_device; i++)
	{
		printf("%d\n", decompress_dat[i]);

	}*/

	for(int z = 0; z < PIC_NUM; z++)
	{
		for (int i = 0; i < deimage_height_; i++)
		{
			unsigned short *buf = new unsigned short[deimage_width_];
			for (int j = 0; j < deimage_width_; j++)
			{
				buf[j] = decompress_dat[z*Den_device+i*deimage_width_ + j];  
			}

			image_data.push_back(buf);
		}



		string decompic = decompress_dir + "//" + com_filename + "_" +to_string(z) + ".tif";

		WriteImage(decompic.c_str(), image_data);

		image_data.clear();
	}
	bool DC_ver = true;
	if (!output_huffman_char || !decompress_lz || !decompress_huff || !decompress_huff_lz || !decompress_pre
		|| !decompress_qua || !decompress_dat) {
		DC_ver = false;
	}

	//verify(decompress_qua);
	//verify(decompress_pre);

	alignedFree(decompress_lz);
	alignedFree(decompress_huff);
	alignedFree(decompress_huff_lz);
	alignedFree(output_huffman_char);

	decompress_pre.release();
	decompress_qua.release();
	decompress_dat.release();

	return DC_ver;
}



/////// HELPER FUNCTIONS ///////
// Initialize the data for the problem. Requires num_devices to be known.
void init_image_data(string original_dir, string *ori_filename, int offset, float cg, float ce, float qu) {


	// 设置host的路径为标准的读取路径
	setCwdToExeDir();

	// 读取Tiff文件
	for(int i = 0; i < PIC_NUM; i++){

		input_file_name = original_dir + "//" + ori_filename[i + offset*PIC_NUM];	//注意这里的//,很容易丢掉
		image_data_store_.clear();	//清除缓存
		read_image(input_file_name.c_str());	//将图片读取到 image_data_store_ 里面去
		if (i == 0){

			n_device = image_height_*image_width_;	// Determine the number of elements processed by this device;
			image_data_array.reset(n_device*PIC_NUM);	// 
		}
		convert_vector_to_array(image_data_store_, image_data_array, image_height_, image_width_, i); // 将向量转换成数组
	}

	// 获取 相机增益，转换误差，量化步长
	camera_gain = cg;
	conversion_error = ce;
	quanstep = qu;	//奇偶

}


// Initializes the OpenCL objects.
bool init_opencl() {

	cl_int status;

	printf("Initializing OpenCL\n");

	// Sets the current working directory to the same directory that contains
	if(!setCwdToExeDir()) { 
		return false;		 
	}

	// Get the OpenCL platform.
	platform = findPlatform("Intel(R) FPGA SDK for OpenCL(TM)");
	if(platform == NULL) {
		printf("ERROR: Unable to find Intel(R) FPGA OpenCL platform.\n");
		return false;
	}

	// Query the available OpenCL device.
	device.reset(getDevices(platform, CL_DEVICE_TYPE_ALL, &num_devices));//回调使得num_devices=1
	printf("Platform: %s\n", getPlatformName(platform).c_str());
	printf("Using %d device(s)\n", num_devices); 
	printf("  %s\n", getDeviceName(device[0]).c_str());

	// Create the context.
	context = clCreateContext(NULL, num_devices, device, &oclContextCallback, NULL, &status);
	checkError(status, "Failed to create context\n");

	// Create the program for all device. Use the first device as the
	// representative device (assuming all device are of the same type).
	std::string binary_file = getBoardBinaryFile("b3d_core", device[0]);
	printf("Using AOCX: %s\n", binary_file.c_str());
	program = createProgramFromBinary(context, binary_file.c_str(), device, num_devices);

	// Build the program that was just created.
	status = clBuildProgram(program, 0, NULL, "", NULL, NULL);
	checkError(status, "Failed to build program\n");

	// Command queue.	
	for(cl_uint i = 0; i < kernel_number; i++){
		queue[i] = clCreateCommandQueue(context, device[0], CL_QUEUE_PROFILING_ENABLE, &status);
		checkError(status, "Failed to create command queue\n");
	}

	// Create kernel
	for(cl_uint i = 0; i < kernel_number; i++){
		kernel[i] = clCreateKernel(program, kernel_name[i], &status);
		checkError(status, "Failed to create kernel\n");
	}
	return true;
}


// Free the resources allocated during initialization
void cleanup() {
	for(unsigned i = 0; i < kernel_number; ++i) {
		if(kernel[i])
			clReleaseKernel(kernel[i]);
		if(queue[i])
			clReleaseCommandQueue(queue[i]);
	}

	if(program)
		clReleaseProgram(program);
	
	if(context)
		clReleaseContext(context);
	
	if(input_buf0)
		clReleaseMemObject(input_buf0);

	if(output_buf_0)
		clReleaseMemObject(output_buf_0);

	if(output_buf_1)
		clReleaseMemObject(output_buf_1);

	if(output_buf_2)
		clReleaseMemObject(output_buf_2);
	
	if(compsize_lz_buf)
		clReleaseMemObject(compsize_lz_buf);

	if(compsize_huffman_buf)
		clReleaseMemObject(compsize_huffman_buf);
	
	if(fvp_buf)
		clReleaseMemObject(fvp_buf);
	
	if(huftable_buf)
		clReleaseMemObject(huftable_buf);
	
	if(output_huffman_buf)
		clReleaseMemObject(output_huffman_buf);
	
	if(input_buf_h)
		clReleaseMemObject(input_buf_h);
}

void read_image(const char *iTifName)
{

	TIFF* itif = TIFFOpen(iTifName, "r");
	
	if (!itif) {
		cout << "Error: Failed to Open File" << endl;
		exit(1);
	}

	total_frame_ = TIFFNumberOfDirectories(itif);

	TIFFGetField(itif, TIFFTAG_IMAGEWIDTH, &image_width_);
	TIFFGetField(itif, TIFFTAG_IMAGELENGTH, &image_height_);
	TIFFGetField(itif, TIFFTAG_BITSPERSAMPLE, &bit_perSample_);    //zdw: set the size of the channels  //图像的深度
	TIFFGetField(itif, TIFFTAG_ROWSPERSTRIP, &row_step_);
	TIFFGetField(itif, TIFFTAG_PHOTOMETRIC, &photometric_);
	TIFFGetField(itif, TIFFTAG_SAMPLEFORMAT, &sample_format_);
	char **des = new char*[2];
	des[0] = new char[100];
	TIFFGetField(itif, TIFFTAG_IMAGEDESCRIPTION, des);
	image_discription_ = des[0];


	//read data from tif file to image_data_store_ vector
	tdata_t buf; //tdata_t is void*
	for (int cur_frame = 0; cur_frame < total_frame_; cur_frame++)
	{
		TIFFSetDirectory(itif, cur_frame);
		for (int row = 0; row < image_height_; row++)
		{//each row 
			buf = _TIFFmalloc(TIFFScanlineSize(itif));
			TIFFReadScanline(itif, buf, row);
			image_data_store_.push_back(buf);
		}
	}
	TIFFClose(itif);
}

template <class T> 
void WriteImage(const char *oTifName, T buf)
{
	TIFF* otif = TIFFOpen(oTifName, "w");
	if (!otif) {
		cout << "Error: Failed to Generate Decompress File" << endl;
		exit(1);
	}


	//write to file
	for (int cur_frame = 0; cur_frame < detotal_frame_; cur_frame++)
	{
		TIFFSetDirectory(otif, cur_frame);
		//set tiff attribute
		TIFFSetField(otif, TIFFTAG_IMAGEWIDTH, deimage_width_);
		TIFFSetField(otif, TIFFTAG_IMAGELENGTH, deimage_height_);
		TIFFSetField(otif, TIFFTAG_BITSPERSAMPLE, debit_perSample_);    // set the size of the channels
		TIFFSetField(otif, TIFFTAG_PHOTOMETRIC, dephotometric_);
		TIFFSetField(otif, TIFFTAG_ROWSPERSTRIP, derow_step_);
		TIFFSetField(otif, TIFFTAG_SAMPLEFORMAT, desample_format_);
		TIFFSetField(otif, TIFFTAG_IMAGEDESCRIPTION, deimage_discription_.c_str());

		for (int row = 0; row < deimage_height_; row++)
		{//each row 
			TIFFWriteScanline(otif, buf[cur_frame*deimage_height_ + row], row);
		}
		TIFFWriteDirectory(otif);
	}
	TIFFClose(otif);
}

void convert_vector_to_array(vector<tdata_t> v,cl_ushort* w,int image_height_,int image_width_,int offset)
{

	//for(int z = 0; z < PIC_NUM; z++)
	//{
		for (int i = 0; i < image_height_; i++)
		{
			cl_ushort *buffer = (cl_ushort*)v[i];
			for (int j = 0; j < image_width_; j++)
			{
				w[offset*image_height_*image_width_+ i*image_width_+j] = buffer[j];
			}
		}
	//}
}


void verify(float *verify_var)
{


	scoped_aligned_ptr<cl_float> data_pho;
	scoped_aligned_ptr<cl_float> data_qua;
	scoped_aligned_ptr<cl_float> data_pre;
	data_pho.reset(n_device*PIC_NUM);
	data_qua.reset(n_device*PIC_NUM);
	data_pre.reset(n_device*PIC_NUM);
	bool ver = true;

	for(cl_uint i = 0; i < n_device*PIC_NUM; i++)
	{
		data_pho[i] =  2 * sqrt((float)image_data_array[i] * camera_gain + conversion_error * conversion_error);// 光子转换
		data_qua[i] = (float)((unsigned short)(data_pho[i] / quanstep) * quanstep); // 量化
		if(data_qua[i] != verify_var[i])
		{
			//printf("%d  %f  %f\n",i, data_qua[i], verify_pre[i]);
			ver = false;
		}

	}

	
	for(cl_uint i = 0; i < n_device*PIC_NUM; i++)
	{
		if(i == 0)
		{
			data_pre[i] = data_qua[i];
		}
		else
		{
			data_pre[i] = data_qua[i] - data_qua[i - 1];		
		}
	
		/*if(data_pre[i] != verify_pre[i])
		{
			ver = false;
		}*/
	}
	if(ver == true)
	{
		printf("--> Verificatin Pass!\n");
	}
	else
	{
		printf("--> Verificatin Error!\n"); 
	}


	//cl_uint cnt = 0;
	//cl_uint rle_cnt = 0;
	//cl_ushort rle_cnt_tmp = 1;
	//scoped_aligned_ptr<cl_ushort> data_rle_len;
	//data_rle_len.reset(n_device);
	//scoped_aligned_ptr<cl_char> data_rle_dat;
	//data_rle_dat.reset(n_device);

	//for(cl_uint i = 0;i < n_device;i++){
	//	if(i != 0){
	//		// tmp
	//		if (data_pre[i] == data_pre[i - 1] ) rle_cnt_tmp++;//if(rle_cnt_tmp == 255) printf("exceed!\n");}
	//		else{
	//				data_rle_len[rle_cnt] = rle_cnt_tmp;
	//				data_rle_dat[rle_cnt] = (char)data_pre[i - 1];
	//				
	//				rle_cnt_tmp = 1; rle_cnt++;
	//		}


	//	}
	//	
	//}
	//
	//data_rle_len[rle_cnt] = rle_cnt_tmp;
	//data_rle_dat[rle_cnt] = (char)data_qua[n_device - 1];
	///*for (cl_uint i = 0; i < rle_cnt+1; i++)
	//{
	//	printf("%d = %d\n",i,data_rle_len[i]);
	//	printf("%d = %d\n",i,data_rle_dat[i]);
	//}*/
	///*printf("%d\n", 3 * (rle_cnt + 1));
	//printf("%d\n", data_rle_len[11]);*/

}