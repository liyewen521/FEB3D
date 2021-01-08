#include "frmmain.h"
#include <QApplication>
#include "myhelper.h"

#include "CL/opencl.h"
#include "AOCLUtils/aocl_utils.h"
#include "b3d_compression.h"

using namespace aocl_utils;


extern cl_platform_id platform;
extern scoped_array<cl_device_id> device; 
extern cl_context context;
extern cl_command_queue queue[kernel_number]; 
extern cl_program program;
extern cl_kernel kernel[kernel_number];
extern cl_uint num_devices;

extern bool init_opencl();

extern bool cl_buffer_first_create;
extern double init_time;

int main(int argc, char *argv[])
{

    QApplication a(argc, argv);

    myHelper::SetUTF8Code();
    //myHelper::SetStyle("black");
    myHelper::SetStyle("blue");
    //myHelper::SetStyle("gray");
    //myHelper::SetStyle("navy");
    myHelper::SetChinese();
	const double init_t1 = getCurrentTimestamp();
	init_opencl();	// opencl init
	const double init_t2 = getCurrentTimestamp();
	init_time = (init_t2 - init_t1) * 1e3;
	cl_buffer_first_create = 1;
    frmMain w;
    w.show();

    return a.exec();
}
