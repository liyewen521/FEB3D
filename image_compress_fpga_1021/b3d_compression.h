#ifndef B3D_COMPRESSION_H
#define B3D_COMPRESSION_H


#define SIMD_WORK_ITEMS 1    


#define N 256				//Ҷ�ӽ����,Ҳ��ʾ8λ�зֺ����ֵ��Χ 0~255
#define M 2*N-1		        //���н������


#define PIC_NUM 100


#define kernel_number 6  


#define BATCH 262144	

//#define COPIES_E 2
//#define COPIES_F 4

typedef struct
{
	unsigned char data;	//���ֵ
	unsigned int weight;//Ȩ��
	int parent;			//˫�׽��
	int lchild;			//���ӽ��
	int rchild;			//�Һ��ӽ��
} HTNode;

typedef struct
{
	unsigned char cd[N+1];		//��Ź�������//ע�������N+1
	unsigned char start;
} HCode;

#endif