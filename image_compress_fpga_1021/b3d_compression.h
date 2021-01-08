#ifndef B3D_COMPRESSION_H
#define B3D_COMPRESSION_H


#define SIMD_WORK_ITEMS 1    


#define N 256				//叶子结点数,也表示8位切分后的数值范围 0~255
#define M 2*N-1		        //树中结点总数


#define PIC_NUM 100


#define kernel_number 6  


#define BATCH 262144	

//#define COPIES_E 2
//#define COPIES_F 4

typedef struct
{
	unsigned char data;	//结点值
	unsigned int weight;//权重
	int parent;			//双亲结点
	int lchild;			//左孩子结点
	int rchild;			//右孩子结点
} HTNode;

typedef struct
{
	unsigned char cd[N+1];		//存放哈夫曼码//注意这个是N+1
	unsigned char start;
} HCode;

#endif