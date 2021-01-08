#include "b3d_compression.h"
#pragma OPENCL EXTENSION cl_intel_channels : enable




channel ushort8 DATA_IN __attribute__((depth(8)));
channel float8 DATA_PHO __attribute__((depth(8)));
channel float8 DATA_QUA __attribute__((depth(8)));
//channel float8 DATA_PRE __attribute__((depth(8)));
//channel float4 DATA_RLE __attribute__((depth(4)));
channel float DATA_PRE __attribute__((depth(1)));
//channel float DATA_RLE[COPIES_E] __attribute__((depth(1)));
//channel uchar DATA_EBC[COPIES_F] __attribute__((depth(1)));



__kernel 
void load_data(     
                __global ushort8* restrict input_image_data		
			   )
{
	//#pragma unroll 32 
	for(uint i = 0;i < BATCH*PIC_NUM;i++){
		ushort8 data_input = input_image_data[i];
		write_channel_intel(DATA_IN, data_input);
	}
}

__kernel 
void photon_transform(
				float camera_gain,     //相机增益
				float conversion_error //转换误差
				)
{
	ushort8 data_in;
	float8 data_pho;

	for(uint i = 0;i < BATCH*PIC_NUM;i++){

		data_in = read_channel_intel(DATA_IN);

		data_pho.s0 =  2 * sqrt((float)data_in.s0*camera_gain+conversion_error*conversion_error);// 光子转换
		data_pho.s1 =  2 * sqrt((float)data_in.s1*camera_gain+conversion_error*conversion_error);// 光子转换
		data_pho.s2 =  2 * sqrt((float)data_in.s2*camera_gain+conversion_error*conversion_error);// 光子转换
		data_pho.s3 =  2 * sqrt((float)data_in.s3*camera_gain+conversion_error*conversion_error);// 光子转换
		data_pho.s4 =  2 * sqrt((float)data_in.s4*camera_gain+conversion_error*conversion_error);// 光子转换
		data_pho.s5 =  2 * sqrt((float)data_in.s5*camera_gain+conversion_error*conversion_error);// 光子转换
		data_pho.s6 =  2 * sqrt((float)data_in.s6*camera_gain+conversion_error*conversion_error);// 光子转换
		data_pho.s7 =  2 * sqrt((float)data_in.s7*camera_gain+conversion_error*conversion_error);// 光子转换

		//data_pho.s8 =  2 * sqrt((float)data_in.s8*camera_gain+conversion_error*conversion_error);// 光子转换
		//data_pho.s9 =  2 * sqrt((float)data_in.s9*camera_gain+conversion_error*conversion_error);// 光子转换
		//data_pho.sa =  2 * sqrt((float)data_in.sa*camera_gain+conversion_error*conversion_error);// 光子转换
		//data_pho.sb =  2 * sqrt((float)data_in.sb*camera_gain+conversion_error*conversion_error);// 光子转换
		//data_pho.sc =  2 * sqrt((float)data_in.sc*camera_gain+conversion_error*conversion_error);// 光子转换
		//data_pho.sd =  2 * sqrt((float)data_in.sd*camera_gain+conversion_error*conversion_error);// 光子转换
		//data_pho.se =  2 * sqrt((float)data_in.se*camera_gain+conversion_error*conversion_error);// 光子转换
		//data_pho.sf =  2 * sqrt((float)data_in.sf*camera_gain+conversion_error*conversion_error);// 光子转换
		
		write_channel_intel(DATA_PHO, data_pho);

	}
}


__kernel 
void quanlitization( 
					 float quanstep         //量化步长
				     )
{
	float8 data_pho;
	float8 data_qua;

	for(uint i = 0;i < BATCH*PIC_NUM;i++){

		data_pho = read_channel_intel(DATA_PHO);

		data_qua.s0 = (float)((ushort)(data_pho.s0 / quanstep) * quanstep); // 量化
		data_qua.s1 = (float)((ushort)(data_pho.s1 / quanstep) * quanstep); // 量化
		data_qua.s2 = (float)((ushort)(data_pho.s2 / quanstep) * quanstep); // 量化
		data_qua.s3 = (float)((ushort)(data_pho.s3 / quanstep) * quanstep); // 量化
		data_qua.s4 = (float)((ushort)(data_pho.s4 / quanstep) * quanstep); // 量化
		data_qua.s5 = (float)((ushort)(data_pho.s5 / quanstep) * quanstep); // 量化
		data_qua.s6 = (float)((ushort)(data_pho.s6 / quanstep) * quanstep); // 量化
		data_qua.s7 = (float)((ushort)(data_pho.s7 / quanstep) * quanstep); // 量化

		//data_qua.s8 = (float)((ushort)(data_pho.s8 / quanstep) * quanstep); // 量化
		//data_qua.s9 = (float)((ushort)(data_pho.s9 / quanstep) * quanstep); // 量化
		//data_qua.sa = (float)((ushort)(data_pho.sa / quanstep) * quanstep); // 量化
		//data_qua.sb = (float)((ushort)(data_pho.sb / quanstep) * quanstep); // 量化
		//data_qua.sc = (float)((ushort)(data_pho.sc / quanstep) * quanstep); // 量化
		//data_qua.sd = (float)((ushort)(data_pho.sd / quanstep) * quanstep); // 量化
		//data_qua.se = (float)((ushort)(data_pho.se / quanstep) * quanstep); // 量化
		//data_qua.sf = (float)((ushort)(data_pho.sf / quanstep) * quanstep); // 量化


		write_channel_intel(DATA_QUA, data_qua);

	}
}


__kernel 
void prediction( 
				)
{
	uint cnt = 0;
	float tmp;
	float data_pre[8];
	
	for(uint i = 0;i < BATCH*PIC_NUM;i++){
		
		float8 data_qua = read_channel_intel(DATA_QUA);
	
		if (cnt == 0)  data_pre[0] = data_qua.s0; 
		else           data_pre[0] = data_qua.s0 - tmp;

		data_pre[1] = data_qua.s1 - data_qua.s0;
		data_pre[2] = data_qua.s2 - data_qua.s1;
		data_pre[3] = data_qua.s3 - data_qua.s2;
		data_pre[4] = data_qua.s4 - data_qua.s3;
		data_pre[5] = data_qua.s5 - data_qua.s4;
		data_pre[6] = data_qua.s6 - data_qua.s5;
		data_pre[7] = data_qua.s7 - data_qua.s6;

		/*data_pre[8] = data_qua.s8 - data_qua.s7;
		data_pre[9] = data_qua.s9 - data_qua.s8;
		data_pre[10] = data_qua.sa - data_qua.s9;
		data_pre[11] = data_qua.sb - data_qua.sa;
		data_pre[12] = data_qua.sc - data_qua.sb;
		data_pre[13] = data_qua.sd - data_qua.sc;
		data_pre[14] = data_qua.se - data_qua.sd;
		data_pre[15] = data_qua.sf - data_qua.se;*/


		for(int j = 0; j < 8; j++){
		
			write_channel_intel(DATA_PRE, data_pre[j]);
		}

		tmp = data_qua.s7;			
		cnt++;

	}
}



__kernel 
void rle_coding( 
					__global ushort* restrict output_rle_len,
					__global char* restrict output_rle_dat,
					__global uint* restrict output_rle_cnt

				)
{
	float data_qua = 0;
	float tmp = 0;
	uint rle_cnt = 0;
	ushort rle_cnt_tmp = 1;
	//ushort2 rle_dat;


	//#pragma unroll 32 
	for(uint i = 0;i < BATCH*8*PIC_NUM;i++){

		data_qua = read_channel_intel(DATA_PRE);
		
		if(i != 0){
			// tmp
			if (data_qua == tmp ) rle_cnt_tmp++;
			else{
					output_rle_len[rle_cnt] = rle_cnt_tmp;
					output_rle_dat[rle_cnt] = (char)tmp;
					
					rle_cnt_tmp = 1; rle_cnt++;
			}


		}
		tmp = data_qua;
	}
	
	output_rle_len[rle_cnt] = rle_cnt_tmp;
	output_rle_dat[rle_cnt] = (char)tmp;
	output_rle_cnt[0] = rle_cnt + 1;

}


//__kernel 
//void rle_coding( 
//					__global ushort* restrict output_rle,
//					__global uint* restrict output_rle_cnt
//
//				)
//{
//	float data_pre;
//	float tmp;
//	uint cnt = 0;
//	uint rle_cnt = 0;
//	uint rle_cnt_tmp = 1;
//	//ushort2 rle_dat;
//
//
//	//#pragma unroll 32 
//	for(uint i = 0;i < BATCH*8;i++){
//
//		data_pre = read_channel_intel(DATA_PRE);
//		/*rle_dat.s0 = 0;
//		rle_dat.s1 = 0;*/
//		if(cnt != 0){
//			// tmp
//			if (data_pre == tmp ) rle_cnt_tmp++;
//			else{
//					output_rle[rle_cnt] = (ushort)rle_cnt_tmp;
//					output_rle[++rle_cnt] = (ushort)tmp;
//					/*rle_dat.s0 = (ushort)rle_cnt_tmp;
//					rle_dat.s1 = (ushort)tmp;*/
//					rle_cnt_tmp = 1; rle_cnt++;
//			}
//			/*write_channel_intel(DATA_RLE[0], rle_dat.s0);
//			write_channel_intel(DATA_RLE[1], rle_dat.s1);*/
//
//		}
//		tmp = data_pre;
//		cnt++;
//	}
//	
//	output_rle[rle_cnt] = (ushort)rle_cnt_tmp;
//	output_rle[++rle_cnt] = (ushort)tmp;
//	//output_rle[BATCH*8*2-1] = (ushort)rle_cnt;
//	output_rle_cnt[0] = rle_cnt;
//
//}









// Copyright (C) 2013-2018 Altera Corporation, San Jose, California, USA. All rights reserved.
// Permission is hereby granted, free of charge, to any person obtaining a copy of this
// software and associated documentation files (the "Software"), to deal in the Software
// without restriction, including without limitation the rights to use, copy, modify, merge,
// publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to
// whom the Software is furnished to do so, subject to the following conditions:
// The above copyright notice and this permission notice shall be included in all copies or
// substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
// OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
// HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
// WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.
// 
// This agreement shall be governed in all respects by the laws of the State of California and
// by the laws of the United States of America.


/*///////////////////////////////////////////////////////////////////////
 *                constants (keep in sync with host)                     *
 ************************************************************************/

//Specifies how many bytes are processed in parallel
//choose 4, 8, 12 or 16 (VEC >= LEN)
#define VEC 16
#define VECX2 (2 * VEC)

//Maximum length of huffman codes
#define MAX_HUFFCODE_BITS 16

//Specifies the maximum match length that we are looking for
// choose 4 or 8 or 16 (LEN <= VEC)
#define LEN 16

//depth of the dictionary buffers
//can also go to depth 1024 which slightly improves quality
//but must change hash function to take advantage of that
#define DEPTH 512


/*///////////////////////////////////////////////////////////////////////
*                       HUFFMAN encoder                                 *
************************************************************************/

// assembles up to VECX2 unsigned char values based on given huffman encoding
// writes up to MAX_HUFFCODE_BITS * VECX2 bits to memory
bool hufenc(unsigned short huftable[256], unsigned char huflen[256], 
        unsigned char *data, bool *valid, bool *dontencode, unsigned short *outdata, 
        unsigned short *leftover, unsigned short *leftover_size) {

    //array that contains the bit position of each symbol
    unsigned short bitpos[VECX2 + 1];
    bitpos[0] = 0;
#pragma unroll
    for (char i = 0; i < VECX2 ; i++) 
    {
        bitpos[i + 1] = bitpos[i] + (valid[i] ? (dontencode[i] ? 8 : huflen[data[i]]) : 0);
    }

    // leftover is an array that carries huffman encoded data not yet written to memory
    // adjust leftover_size with the number of bits to write this time
    unsigned short prev_cycle_offset = *leftover_size;
    *leftover_size += bitpos[VECX2];

    //we'll write this cycle if we have collected enough data (VECX2 shorts or more)
    bool write = *leftover_size & (VECX2 * MAX_HUFFCODE_BITS);

    //subtract VECX2 shorts from leftover size (if it's bigger than VECX2) because we'll write those out this cycle
    *leftover_size &= ~(VECX2 * MAX_HUFFCODE_BITS);

    // Adjust bitpos based on leftover offset from previous cycle
#pragma unroll
    for (char i = 0; i < VECX2; i++) 
    {
        bitpos[i] += prev_cycle_offset;
    }

    // Huffman codes have any bit alignement, so they can spill onto two shorts in the output array
    // use ushort2 to keep each part of the code separate
    // Iterate over all codes and construct ushort2 containing the code properly aligned
    ushort2 code[VECX2];
#pragma unroll
    for (char i = 0; i < VECX2; i++) 
    {
        unsigned short curr_code = dontencode[i] ? data[i] : huftable[data[i]];
        unsigned char curr_code_len = dontencode[i] ? 8 : huflen[data[i]];
        unsigned char bitpos_in_short = bitpos[i] & 0x0F;

        unsigned int temp = (unsigned int)curr_code << 16;
        unsigned short temp1 = temp >> (curr_code_len + bitpos_in_short);
        unsigned short temp2 = 0;
        if(curr_code_len + bitpos_in_short - 16 >= 0)
            temp2 = temp >> (curr_code_len + bitpos_in_short - 16);

        code[i] = valid[i] ? (ushort2)(temp1, temp2) : (ushort2)(0, 0); 
    }

    // Iterate over all destination locations and gather the required data
    unsigned short new_leftover[VECX2];
#pragma unroll
    for (char i = 0; i < VECX2; i++) 
    {
        new_leftover[i] = 0;
        outdata[i] = 0;
#pragma unroll
        for (char j = 0; j < VECX2; j++) 
        {
            //figure out whether code[j] goes into bucket[i]
            bool match_first  = ((bitpos[j] >> 4) & (VECX2 - 1)) == i;
            bool match_second = ((bitpos[j] >> 4) & (VECX2 - 1)) == ((i - 1) & (VECX2 - 1));

            //if code[j] maps onto current bucket then OR its code, else OR with 0
            unsigned short component = match_first ? code[j].x : (match_second ? code[j].y : 0);

            //overflow from VECX2 shorts, need to move onto new_leftover
            bool use_later = (bitpos[j] & (VECX2 * MAX_HUFFCODE_BITS)) || 
                (match_second && (((bitpos[j] >> 4) & (VECX2 - 1)) == VECX2 - 1));

            //write to output
            outdata[i] |= use_later ? 0 : component;
            new_leftover[i] |= use_later ? component : 0;
        }
    }

    // Apply previous leftover on the outdata
    // Also, if didn't write, apply prev leftover onto newleftover
#pragma unroll
    for (char i = 0; i < VECX2; i++) 
    {
        outdata[i] |= leftover[i];
        if (write) 
            leftover[i] = new_leftover[i];
        else 
            leftover[i] |= outdata[i];
    }

    return write;
}

/*/////////////////////////////////////////////////////////////////////////
*                       GZIP top-level kernel                             *
**************************************************************************/

void kernel gzip
(
 global unsigned char  *restrict input,
 global unsigned int   *restrict huftableOrig, 
 unsigned int insize,
 unsigned char marker,
 global unsigned int   *restrict fvp,
 global unsigned short *restrict output_huffman,
 global unsigned int   *restrict compsize_lz,
 global unsigned int   *restrict compsize_huffman
 )
{	

    // if the insize is 0, clear the storage
    bool reset = true;

    //-------------------------------------
    //   Hash Table(s)
    //-------------------------------------

    //each row buffers VEC bytes of data and we have 
    //256 rows each corresponding to an 8 bit symbol 

    //unsigned char dictionary[256][VEC][VEC];
    // symbols we have---------|    |    |
    // VEC symbols per line---------|    |
    // VEC dicts for parallelism---------|

    unsigned char dictionary_0[DEPTH][LEN];
    unsigned char dictionary_1[DEPTH][LEN];
    unsigned char dictionary_2[DEPTH][LEN];
    unsigned char dictionary_3[DEPTH][LEN];
#if VEC > 4
    unsigned char dictionary_4[DEPTH][LEN];
    unsigned char dictionary_5[DEPTH][LEN];
    unsigned char dictionary_6[DEPTH][LEN];
    unsigned char dictionary_7[DEPTH][LEN];
#endif
#if VEC > 8
    unsigned char dictionary_8[DEPTH][LEN];
    unsigned char dictionary_9[DEPTH][LEN];
    unsigned char dictionary_10[DEPTH][LEN];
    unsigned char dictionary_11[DEPTH][LEN];
#endif
#if VEC > 12
    unsigned char dictionary_12[DEPTH][LEN];
    unsigned char dictionary_13[DEPTH][LEN];
    unsigned char dictionary_14[DEPTH][LEN];
    unsigned char dictionary_15[DEPTH][LEN];
#endif

    //here we store the inpos of each entry
    //unsigned int dict_offset[DEPTH][VEC];
    // one per dict line---------|    |
    // one per dictionary-------------|

    unsigned int dict_offset_0[DEPTH];
    unsigned int dict_offset_1[DEPTH];
    unsigned int dict_offset_2[DEPTH];
    unsigned int dict_offset_3[DEPTH];
#if VEC > 4
    unsigned int dict_offset_4[DEPTH];
    unsigned int dict_offset_5[DEPTH];
    unsigned int dict_offset_6[DEPTH];
    unsigned int dict_offset_7[DEPTH];
#endif
#if VEC > 8
    unsigned int dict_offset_8[DEPTH];
    unsigned int dict_offset_9[DEPTH];
    unsigned int dict_offset_10[DEPTH];
    unsigned int dict_offset_11[DEPTH];
#endif
#if VEC > 12
    unsigned int dict_offset_12[DEPTH];
    unsigned int dict_offset_13[DEPTH];
    unsigned int dict_offset_14[DEPTH];
    unsigned int dict_offset_15[DEPTH];
#endif

    // This is the window of data on which we look for matches
    // We fetch twice our data size because we have VEC offsets

    unsigned char current_window[VECX2];

    // This is the window of data on which we look for matches 
    // We fetch twice our data size because we have VEC offsets

    unsigned char compare_window[LEN][VEC][VEC];
    // VEC bytes per dict---------|    |    |
    // VEC dictionaries----------------|    |
    // one for each curr win offset---------|

    //load offset into these arrays
    unsigned int compare_offset[VEC][VEC];
    // one per VEC bytes---------|    |
    // one for each compwin-----------|

    // carries partially assembled huffman output_lz
    unsigned short leftover[VECX2]; 
    for(char i = 0; i < VECX2; i++) leftover[i] = 0;

    unsigned short leftover_size = 0;

    unsigned short huftable[256];
    unsigned char huflen[256];
    unsigned int code = 0;
    unsigned char len;

    // Load Huffman codes

    for (short i = 0; i < 256; i++) 
    {
        unsigned int a = huftableOrig[i]; 
        code = a & 0xFFFF;
        len = a >> 16;

        huftable[i] = code;
        huflen[i] = len;
    }

    // Initialize input stream position
    unsigned int inpos = 0;

    unsigned int outpos_lz = 0;
    char first_valid_pos = 0;
    unsigned int outpos_huffman = 0;

    unsigned short mod_hash = 0;

    do
    {
        //-----------------------------
        // Prepare current window
        //-----------------------------

        //shift current window
#pragma unroll
        for(char i = 0; i < VEC; i++)
            current_window[i] = current_window[i+VEC];

        //load in new data
#pragma unroll
        for(char i = 0; i < VEC; i++)
            current_window[VEC+i] = input[inpos+i];

        //-----------------------------
        // Compute hash
        //-----------------------------

        unsigned short hash[VEC];

#pragma unroll VEC
        for(char i = 0; i < VEC; i++)
        {	
            unsigned short first_shifted  = current_window[i];
            hash[i] = reset ? mod_hash : (first_shifted << 1) ^ current_window[i+1] ^ (current_window[i+2]) ;
        }

        mod_hash++;

        //-----------------------------
        // Dictionary look-up
        //-----------------------------

        //loop over VEC compare windows, each has a different hash
#pragma unroll
        for(char i = 0; i < VEC; i++)
            //loop over all VEC bytes
#pragma unroll
            for(char j = 0; j < LEN; j++)
            {
                compare_window[j][0][i] = dictionary_0[hash[i]][j];
                compare_window[j][1][i] = dictionary_1[hash[i]][j];
                compare_window[j][2][i] = dictionary_2[hash[i]][j];
                compare_window[j][3][i] = dictionary_3[hash[i]][j];
#if VEC > 4
                compare_window[j][4][i] = dictionary_4[hash[i]][j];
                compare_window[j][5][i] = dictionary_5[hash[i]][j];
                compare_window[j][6][i] = dictionary_6[hash[i]][j];
                compare_window[j][7][i] = dictionary_7[hash[i]][j];
#endif
#if VEC > 8
                compare_window[j][8][i]  = dictionary_8[hash[i]][j];
                compare_window[j][9][i]  = dictionary_9[hash[i]][j];
                compare_window[j][10][i] = dictionary_10[hash[i]][j];
                compare_window[j][11][i] = dictionary_11[hash[i]][j];
#endif
#if VEC > 12
                compare_window[j][12][i] = dictionary_12[hash[i]][j];
                compare_window[j][13][i] = dictionary_13[hash[i]][j];
                compare_window[j][14][i] = dictionary_14[hash[i]][j];
                compare_window[j][15][i] = dictionary_15[hash[i]][j];
#endif
            }

        //loop over compare windows
#pragma unroll
        for(char i = 0; i < VEC; i++)
        {
            //loop over frames in this compare window (they come from different dictionaries)
            compare_offset[0][i] = dict_offset_0[hash[i]];
            compare_offset[1][i] = dict_offset_1[hash[i]];
            compare_offset[2][i] = dict_offset_2[hash[i]];
            compare_offset[3][i] = dict_offset_3[hash[i]];
#if VEC > 4
            compare_offset[4][i] = dict_offset_4[hash[i]];
            compare_offset[5][i] = dict_offset_5[hash[i]];
            compare_offset[6][i] = dict_offset_6[hash[i]];
            compare_offset[7][i] = dict_offset_7[hash[i]];
#endif
#if VEC > 8
            compare_offset[8][i]  = dict_offset_8[hash[i]];
            compare_offset[9][i]  = dict_offset_9[hash[i]];
            compare_offset[10][i] = dict_offset_10[hash[i]];
            compare_offset[11][i] = dict_offset_11[hash[i]];
#endif
#if VEC > 12
            compare_offset[12][i] = dict_offset_12[hash[i]];
            compare_offset[13][i] = dict_offset_13[hash[i]];
            compare_offset[14][i] = dict_offset_14[hash[i]];
            compare_offset[15][i] = dict_offset_15[hash[i]];
#endif
        }

        //-----------------------------
        // Dictionary update
        //-----------------------------

        //loop over different dictionaries to store different frames
        //store one frame per dictionary
        //loop over VEC bytes to store
#pragma unroll
        for(char i = 0; i < LEN; i++)
        {
            //store actual bytes
            dictionary_0[hash[0]][i] = current_window[i+0];
            dictionary_1[hash[1]][i] = current_window[i+1];
            dictionary_2[hash[2]][i] = current_window[i+2];
            dictionary_3[hash[3]][i] = current_window[i+3];
#if VEC > 4
            dictionary_4[hash[4]][i] = current_window[i+4];
            dictionary_5[hash[5]][i] = current_window[i+5];
            dictionary_6[hash[6]][i] = current_window[i+6];
            dictionary_7[hash[7]][i] = current_window[i+7];
#endif
#if VEC > 8
            dictionary_8[hash[8]][i]  = current_window[i+8];
            dictionary_9[hash[9]][i]  = current_window[i+9];
            dictionary_10[hash[10]][i] = current_window[i+10];
            dictionary_11[hash[11]][i] = current_window[i+11];
#endif
#if VEC > 12
            dictionary_12[hash[12]][i] = current_window[i+12];
            dictionary_13[hash[13]][i] = current_window[i+13];
            dictionary_14[hash[14]][i] = current_window[i+14];
            dictionary_15[hash[15]][i] = current_window[i+15];
#endif
        }

        //loop over VEC different dictionaries and write one word to each
        dict_offset_0[hash[0]] = reset ? 0 : inpos - VEC + 0;
        dict_offset_1[hash[1]] = reset ? 0 : inpos - VEC + 1;
        dict_offset_2[hash[2]] = reset ? 0 : inpos - VEC + 2;
        dict_offset_3[hash[3]] = reset ? 0 : inpos - VEC + 3;
#if VEC > 4
        dict_offset_4[hash[4]] = reset ? 0 : inpos - VEC + 4;
        dict_offset_5[hash[5]] = reset ? 0 : inpos - VEC + 5;
        dict_offset_6[hash[6]] = reset ? 0 : inpos - VEC + 6;
        dict_offset_7[hash[7]] = reset ? 0 : inpos - VEC + 7;
#endif
#if VEC > 8
        dict_offset_8[hash[8]]   = reset ? 0 : inpos - VEC + 8;
        dict_offset_9[hash[9]]   = reset ? 0 : inpos - VEC + 9;
        dict_offset_10[hash[10]] = reset ? 0 : inpos - VEC + 10;
        dict_offset_11[hash[11]] = reset ? 0 : inpos - VEC + 11;
#endif
#if VEC > 12
        dict_offset_12[hash[12]] = reset ? 0 : inpos - VEC + 12;
        dict_offset_13[hash[13]] = reset ? 0 : inpos - VEC + 13;
        dict_offset_14[hash[14]] = reset ? 0 : inpos - VEC + 14;
        dict_offset_15[hash[15]] = reset ? 0 : inpos - VEC + 15;
#endif

        //-----------------------------
        // Match search
        //-----------------------------

        //arrays to store length, best length etc..
        ushort length_bool[VEC][VEC];

        //loop over each comparison window frame
        //one comes from each dictionary
#pragma unroll
        for(char i = 0; i < VEC; i++ )
        {
            //initialize length and done
#pragma unroll
            for(char l = 0; l < VEC; l++)
            {
                length_bool[i][l] = 0;
            }

            //loop over each current window
#pragma unroll
            for(char j = 0; j < VEC ; j++)
            {
                //loop over each char in the current window
                //and corresponding char in comparison window
#pragma unroll
                for(char k = 0; k < LEN ; k++)
                {	
                    length_bool[i][j] |= (current_window[i + k] == compare_window[k][j][i]) << k;
                }
            }
        }

        unsigned short filtered_length_bool[VEC][VEC];

        //after this the result is all 1's from the begining for however long my match is
        // e.g. 00000111 means a match length of 3
#pragma unroll
        for(char i = 0; i < VEC; i++)
        {
#pragma unroll
            for(char j = 0; j < VEC; j++)
            {
                unsigned short curr_match = length_bool[i][j];
                curr_match = curr_match & ((curr_match << 1) | 0x01);
                curr_match = curr_match & ((curr_match << 2) | 0x03);
                curr_match = curr_match & ((curr_match << 4) | 0x0f);
                curr_match = curr_match & ((curr_match << 8) | 0xff);
                filtered_length_bool[i][j] = curr_match;
            }
        }

        //this holds the max match found per current window
        unsigned short max_match[VEC];

        //OR all the matches for each current window to get the best one
#pragma unroll
        for(char i = 0; i < VEC; i++)
        {
            max_match[i] = 0;
#pragma unroll
            for(char j = 0; j < VEC; j++)
            {
                max_match[i] |=  filtered_length_bool[i][j];
            }
        }

        unsigned short u_bestlength[VEC];
        unsigned int   bestoffset[VEC];

        //initialize u_bestlength
#pragma unroll
        for(char i = 0; i < VEC; i++)
        {
            u_bestlength[i] = 0;
            bestoffset[i] = 0;
        }

        //for each current window
#pragma unroll
        for( char i = 0; i < VEC; i++ )
        {
            //is this the best length? if it is, the result of XOR should be 0
#pragma unroll
            for( char j = 0; j < VEC; j++ )
            {
                bestoffset[i]    = ((max_match[i] ^ filtered_length_bool[i][j]) == 0) && (compare_offset[j][i] != 0) && ((inpos-VEC+i)-(compare_offset[j][i]) < 0x40000) ? (inpos-VEC+i)-(compare_offset[j][i]) : bestoffset[i];
                u_bestlength[i] |= ((max_match[i] ^ filtered_length_bool[i][j]) == 0) && (compare_offset[j][i] != 0) && ((inpos-VEC+i)-(compare_offset[j][i]) < 0x40000) ? max_match[i] : 0;
            }
        }

        unsigned short u_bestlength_onehot[VEC];

        //one-hot-encode u_bestlength
#pragma unroll
        for( char i = 0; i < VEC; i++ )
        {
            unsigned int onehot = (u_bestlength[i] + 1) >> 1;
            u_bestlength_onehot[i] = onehot;
        }

        char bestlength[VEC];

        //convert from one-hot to binary
#pragma unroll
        for(char i = 0; i < VEC; i++)
            bestlength[i] = ((u_bestlength_onehot[i] & 0x8000) ? 0x10 : 0x00) | 
                ((u_bestlength_onehot[i] & 0x7f80) ? 0x08 : 0x00) | 
                ((u_bestlength_onehot[i] & 0x7878) ? 0x04 : 0x00) | 
                ((u_bestlength_onehot[i] & 0x6666) ? 0x02 : 0x00) | 
                ((u_bestlength_onehot[i] & 0x5555) ? 0x01 : 0x00);


        //-----------------------------
        // Filter matches step 1
        //-----------------------------

        //remove matches with offsets that are <= 0: this means they're self-matching or didn't match
        //and	
        //keep only the matches that, when encoded, take fewer bytes than the actual match length				
#pragma unroll
        for(char i = 0; i < VEC; i++)
            bestlength[i] = ( (bestlength[i] >= 5) ||
                    ((bestlength[i] == 4) && (bestoffset[i] < 0x800))) ? bestlength[i] : 0;

        //remove matches covered by previous cycle
#pragma unroll
        for(char i = 0; i < VEC; i++)
            bestlength[i] = i < first_valid_pos ? -1 : bestlength[i];

        //-----------------------------
        // Assign first_valid_pos
        //-----------------------------

        //this is the most important variable in the world --> it is the only loop-carried one
        first_valid_pos = 0;

#pragma unroll
        for(char i = 0; i < VEC; i++)
            first_valid_pos = bestlength[i] <= 0 ? first_valid_pos : i + bestlength[i];

        int first_valid_full = first_valid_pos;

        if(first_valid_pos >= VEC)
            first_valid_pos -= VEC;
        else
            first_valid_pos = 0;

        //-----------------------------
        // Filter matches "last-fit"
        //-----------------------------

        //pre-fit stage removes the later matches that have EXACTLY the same reach
#pragma unroll
        for(char i = 0; i < VEC-1; i++)
#pragma unroll
            for(char j = 1; j < VEC; j++)
                bestlength[j] = ((bestlength[i] + i) == (bestlength[j] + j)) && i < j && bestlength[j] > 0 && bestlength[i] > 0 ? 0 : bestlength[j];
        //                 reach of bl[i]         reach of bl[j]	   

        //look for location of golden matcher
        int golden_matcher = 0;
#pragma unroll
        for(char i = 0; i < VEC; i++)
            golden_matcher = (bestlength[i]+i == (first_valid_full)) ? i : golden_matcher;

        //if something covers golden matcher --> remove it!
#pragma unroll
        for(char i = 0; i < VEC; i++)
            bestlength[i] = ((bestlength[i] + i) > golden_matcher) && i < golden_matcher && bestlength[i] != -1 ? 0 : bestlength[i];

        //another step to remove literals that will be covered by prior matches
        //set those to '-1' because we will do nothing for them, not even emit symbol
#pragma unroll
        for(char i = 0; i < VEC-1; i++)
#pragma unroll VEC
            for(char j = 1; j < VEC-i; j++)
                bestlength[i+j] = bestlength[i] > j ? -1 : bestlength[i+j];

        //-----------------------------
        // Encode LZ bytes
        //-----------------------------

        unsigned char output_buffer[VECX2];
        int output_buffer_size = 0;

        bool dontencode[VECX2];

#pragma unroll
        for (int i = 0; i < VECX2; i++) {
            output_buffer[i] = 0;
            dontencode[i] = true;
        }

        //output marker byte at start
        if (reset) {
            if (mod_hash & DEPTH) {
                reset = false;
                output_buffer[output_buffer_size] = marker;
                dontencode[output_buffer_size++] = false;
            }
        } else {

            //loop over all chars in this cycle and compose output 
#pragma unroll
            for(char i = 0; i < VEC; i++)
            {
                if(bestlength[i] == 0)
                {
                    dontencode[output_buffer_size] = false;
                    output_buffer[output_buffer_size++] = current_window[i];

                    if(current_window[i] == marker)
                    {
                        dontencode[output_buffer_size] = true;
                        output_buffer[output_buffer_size++] = 0;
                    }
                }
                else if(bestlength[i] > 0)
                {
                    //1-output marker
                    dontencode[output_buffer_size] = false;
                    output_buffer[output_buffer_size++] = marker;

                    //2-output bestlength

                    //fit b.l. in 4 bits and put in upper m.s.b's
                    unsigned char bestlength_byte = (bestlength[i] - 3) << 4;

                    //concat with lower 4 bestoffset bytes
                    unsigned int offset = bestoffset[i];
                    bestlength_byte |= (offset & 0xf);

                    //write to output_buffer
                    dontencode[output_buffer_size] = true;
                    output_buffer[output_buffer_size++] = bestlength_byte;

                    //3-output bestoffset

                    //check how many more bytes we need for bestoffset (either one or two)
                    int extra_offset_bytes = 0;

                    if(offset < 0x800) //offset needs only one extra byte
                    {
                        dontencode[output_buffer_size] = true;
                        output_buffer[output_buffer_size++] = (offset >> 4) & 0x7f;
                    }
                    else //offset needs two extra bytes
                    {
                        dontencode[output_buffer_size] = true;
                        output_buffer[output_buffer_size++] =  (offset >> 4)  | 0x80;
                        dontencode[output_buffer_size] = true;
                        output_buffer[output_buffer_size++] = ((offset >> 11) & 0x7f);
                    }
                }
            }
        }
        outpos_lz += output_buffer_size;

        //-----------------------------
        // Huffman encoding
        //-----------------------------

        //valid array contains '1' if there is data at this output_buffer position, zero otherwise		
        bool valid[VECX2];

#pragma unroll
        for(char i = 0; i < VECX2; i++)
        {
            if(i < output_buffer_size)
                valid[i] = true;
            else
                valid[i] = false;
        }

        unsigned short outdata[VECX2];
        bool write = hufenc(huftable, huflen, output_buffer, valid, dontencode, outdata, leftover, &leftover_size);

#pragma unroll
        for (char i = 0; i < VECX2; i++) 
        {
            output_huffman[VECX2 * outpos_huffman + i] = (outdata[i]);
        }
        outpos_huffman = write ? outpos_huffman + 1 : outpos_huffman;

        //-----------------------------
        // Housekeeping
        //-----------------------------

        //increment input position
        inpos += VEC;
        if (reset) inpos = 0;

    } while(inpos < insize);

    //change to count of shorts
    outpos_huffman = outpos_huffman * VECX2;
    //write remaining bits
    for (char i = 0; i < VECX2; i++) 
    {
        output_huffman[outpos_huffman + i] = (leftover[i]);
    }

    outpos_huffman *= 2;

    outpos_huffman = outpos_huffman + (leftover_size >> 3) + ((leftover_size & 0x7) != 0);

    //have to output first_valid_pos to tell 
    //the host from where to start writing
    *fvp = first_valid_pos;

    //return compressed size as size of chars
    *compsize_huffman = outpos_huffman;

    //return lz compressed size
    *compsize_lz = outpos_lz;	
}






//// Copyright (C) 2013-2018 Altera Corporation, San Jose, California, USA. All rights reserved.
//// Permission is hereby granted, free of charge, to any person obtaining a copy of this
//// software and associated documentation files (the "Software"), to deal in the Software
//// without restriction, including without limitation the rights to use, copy, modify, merge,
//// publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to
//// whom the Software is furnished to do so, subject to the following conditions:
//// The above copyright notice and this permission notice shall be included in all copies or
//// substantial portions of the Software.
//// 
//// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
//// OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
//// HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//// WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
//// OTHER DEALINGS IN THE SOFTWARE.
//// 
//// This agreement shall be governed in all respects by the laws of the State of California and
//// by the laws of the United States of America.
//
//
///*///////////////////////////////////////////////////////////////////////
// *                constants (keep in sync with host)                     *
// ************************************************************************/
//
////Specifies how many bytes are processed in parallel
////choose 4, 8, 12 or 16 (VEC >= LEN)
//#define VEC 16
//#define VECX2 (2 * VEC)
//
////Maximum length of huffman codes
//#define MAX_HUFFCODE_BITS 16
//
////Specifies the maximum match length that we are looking for
//// choose 4 or 8 or 16 (LEN <= VEC)
//#define LEN 16
//
////depth of the dictionary buffers
////can also go to depth 1024 which slightly improves quality
////but must change hash function to take advantage of that
//#define DEPTH 512
//
//
///*///////////////////////////////////////////////////////////////////////
//*                       HUFFMAN encoder                                 *
//************************************************************************/
//
//// assembles up to VECX2 unsigned char values based on given huffman encoding
//// writes up to MAX_HUFFCODE_BITS * VECX2 bits to memory
//bool hufenc(unsigned short huftable[256], unsigned char huflen[256], 
//        unsigned char *data, bool *valid, bool *dontencode, unsigned short *outdata, 
//        unsigned short *leftover, unsigned short *leftover_size) {
//
//    //array that contains the bit position of each symbol
//    unsigned short bitpos[VECX2 + 1];
//    bitpos[0] = 0;
//#pragma unroll
//    for (char i = 0; i < VECX2 ; i++) 
//    {
//        bitpos[i + 1] = bitpos[i] + (valid[i] ? (dontencode[i] ? 8 : huflen[data[i]]) : 0);
//    }
//
//    // leftover is an array that carries huffman encoded data not yet written to memory
//    // adjust leftover_size with the number of bits to write this time
//    unsigned short prev_cycle_offset = *leftover_size;
//    *leftover_size += bitpos[VECX2];
//
//    //we'll write this cycle if we have collected enough data (VECX2 shorts or more)
//    bool write = *leftover_size & (VECX2 * MAX_HUFFCODE_BITS);
//
//    //subtract VECX2 shorts from leftover size (if it's bigger than VECX2) because we'll write those out this cycle
//    *leftover_size &= ~(VECX2 * MAX_HUFFCODE_BITS);
//
//    // Adjust bitpos based on leftover offset from previous cycle
//#pragma unroll
//    for (char i = 0; i < VECX2; i++) 
//    {
//        bitpos[i] += prev_cycle_offset;
//    }
//
//    // Huffman codes have any bit alignement, so they can spill onto two shorts in the output array
//    // use ushort2 to keep each part of the code separate
//    // Iterate over all codes and construct ushort2 containing the code properly aligned
//    ushort2 code[VECX2];
//#pragma unroll
//    for (char i = 0; i < VECX2; i++) 
//    {
//        unsigned short curr_code = dontencode[i] ? data[i] : huftable[data[i]];
//        unsigned char curr_code_len = dontencode[i] ? 8 : huflen[data[i]];
//        unsigned char bitpos_in_short = bitpos[i] & 0x0F;
//
//        unsigned int temp = (unsigned int)curr_code << 16;
//        unsigned short temp1 = temp >> (curr_code_len + bitpos_in_short);
//        unsigned short temp2 = 0;
//        if(curr_code_len + bitpos_in_short - 16 >= 0)
//            temp2 = temp >> (curr_code_len + bitpos_in_short - 16);
//
//        code[i] = valid[i] ? (ushort2)(temp1, temp2) : (ushort2)(0, 0); 
//    }
//
//    // Iterate over all destination locations and gather the required data
//    unsigned short new_leftover[VECX2];
//#pragma unroll
//    for (char i = 0; i < VECX2; i++) 
//    {
//        new_leftover[i] = 0;
//        outdata[i] = 0;
//#pragma unroll
//        for (char j = 0; j < VECX2; j++) 
//        {
//            //figure out whether code[j] goes into bucket[i]
//            bool match_first  = ((bitpos[j] >> 4) & (VECX2 - 1)) == i;
//            bool match_second = ((bitpos[j] >> 4) & (VECX2 - 1)) == ((i - 1) & (VECX2 - 1));
//
//            //if code[j] maps onto current bucket then OR its code, else OR with 0
//            unsigned short component = match_first ? code[j].x : (match_second ? code[j].y : 0);
//
//            //overflow from VECX2 shorts, need to move onto new_leftover
//            bool use_later = (bitpos[j] & (VECX2 * MAX_HUFFCODE_BITS)) || 
//                (match_second && (((bitpos[j] >> 4) & (VECX2 - 1)) == VECX2 - 1));
//
//            //write to output
//            outdata[i] |= use_later ? 0 : component;
//            new_leftover[i] |= use_later ? component : 0;
//        }
//    }
//
//    // Apply previous leftover on the outdata
//    // Also, if didn't write, apply prev leftover onto newleftover
//#pragma unroll
//    for (char i = 0; i < VECX2; i++) 
//    {
//        outdata[i] |= leftover[i];
//        if (write) 
//            leftover[i] = new_leftover[i];
//        else 
//            leftover[i] |= outdata[i];
//    }
//
//    return write;
//}
//
///*/////////////////////////////////////////////////////////////////////////
//*                       GZIP top-level kernel                             *
//**************************************************************************/
//
//void kernel gzip
//(
// global unsigned char  *restrict input,
// global unsigned int   *restrict huftableOrig, 
// unsigned int insize,
// unsigned char marker,
// global unsigned int   *restrict fvp,
// global unsigned short *restrict output_huffman,
// global unsigned int   *restrict compsize_lz,
// global unsigned int   *restrict compsize_huffman
// )
//{	
//
//    // if the insize is 0, clear the storage
//    bool reset = true;
//
//    //-------------------------------------
//    //   Hash Table(s)
//    //-------------------------------------
//
//    //each row buffers VEC bytes of data and we have 
//    //256 rows each corresponding to an 8 bit symbol 
//
//    //unsigned char dictionary[256][VEC][VEC];
//    // symbols we have---------|    |    |
//    // VEC symbols per line---------|    |
//    // VEC dicts for parallelism---------|
//
//    unsigned char dictionary_0[DEPTH][LEN];
//    unsigned char dictionary_1[DEPTH][LEN];
//    unsigned char dictionary_2[DEPTH][LEN];
//    unsigned char dictionary_3[DEPTH][LEN];
//#if VEC > 4
//    unsigned char dictionary_4[DEPTH][LEN];
//    unsigned char dictionary_5[DEPTH][LEN];
//    unsigned char dictionary_6[DEPTH][LEN];
//    unsigned char dictionary_7[DEPTH][LEN];
//#endif
//#if VEC > 8
//    unsigned char dictionary_8[DEPTH][LEN];
//    unsigned char dictionary_9[DEPTH][LEN];
//    unsigned char dictionary_10[DEPTH][LEN];
//    unsigned char dictionary_11[DEPTH][LEN];
//#endif
//#if VEC > 12
//    unsigned char dictionary_12[DEPTH][LEN];
//    unsigned char dictionary_13[DEPTH][LEN];
//    unsigned char dictionary_14[DEPTH][LEN];
//    unsigned char dictionary_15[DEPTH][LEN];
//#endif
//
//    //here we store the inpos of each entry
//    //unsigned int dict_offset[DEPTH][VEC];
//    // one per dict line---------|    |
//    // one per dictionary-------------|
//
//    unsigned int dict_offset_0[DEPTH];
//    unsigned int dict_offset_1[DEPTH];
//    unsigned int dict_offset_2[DEPTH];
//    unsigned int dict_offset_3[DEPTH];
//#if VEC > 4
//    unsigned int dict_offset_4[DEPTH];
//    unsigned int dict_offset_5[DEPTH];
//    unsigned int dict_offset_6[DEPTH];
//    unsigned int dict_offset_7[DEPTH];
//#endif
//#if VEC > 8
//    unsigned int dict_offset_8[DEPTH];
//    unsigned int dict_offset_9[DEPTH];
//    unsigned int dict_offset_10[DEPTH];
//    unsigned int dict_offset_11[DEPTH];
//#endif
//#if VEC > 12
//    unsigned int dict_offset_12[DEPTH];
//    unsigned int dict_offset_13[DEPTH];
//    unsigned int dict_offset_14[DEPTH];
//    unsigned int dict_offset_15[DEPTH];
//#endif
//
//    // This is the window of data on which we look for matches
//    // We fetch twice our data size because we have VEC offsets
//
//    unsigned char current_window[VECX2];
//
//    // This is the window of data on which we look for matches 
//    // We fetch twice our data size because we have VEC offsets
//
//    unsigned char compare_window[LEN][VEC][VEC];
//
//    // VEC bytes per dict---------|    |    |
//    // VEC dictionaries----------------|    |
//    // one for each curr win offset---------|
//
//    //load offset into these arrays
//    unsigned int compare_offset[VEC][VEC];
//    // one per VEC bytes---------|    |
//    // one for each compwin-----------|
//
//    // carries partially assembled huffman output_lz
//    unsigned short leftover[VECX2]; 
//    for(char i = 0; i < VECX2; i++) leftover[i] = 0;
//
//    unsigned short leftover_size = 0;
//
//    unsigned short huftable[256];
//    unsigned char huflen[256];
//    unsigned int code = 0;
//    unsigned char len;
//
//    // Load Huffman codes
//
//    for (short i = 0; i < 256; i++) 
//    {
//        unsigned int a = huftableOrig[i]; 
//        code = a & 0xFFFF;
//        len = a >> 16;
//
//        huftable[i] = code;
//        huflen[i] = len;
//    }
//
//    // Initialize input stream position
//    unsigned int inpos = 0;
//
//    unsigned int outpos_lz = 0;
//    char first_valid_pos = 0;
//    unsigned int outpos_huffman = 0;
//
//    unsigned short mod_hash = 0;
//
//    do
//    {
//        //-----------------------------
//        // Prepare current window
//        //-----------------------------
//
//        //shift current window
//#pragma unroll
//        for(char i = 0; i < VEC; i++)
//            current_window[i] = current_window[i+VEC];
//
//        //load in new data
//#pragma unroll
//        for(char i = 0; i < VEC; i++)
//            current_window[VEC+i] = input[inpos+i];
//
//        //-----------------------------
//        // Compute hash
//        //-----------------------------
//
//        unsigned short hash[VEC];
//
//#pragma unroll VEC
//        for(char i = 0; i < VEC; i++)
//        {	
//            unsigned short first_shifted  = current_window[i];
//            hash[i] = reset ? mod_hash : (first_shifted << 1) ^ current_window[i+1] ^ (current_window[i+2]) ;
//        }
//
//        mod_hash++;
//
//        //-----------------------------
//        // Dictionary look-up
//        //-----------------------------
//
//        //loop over VEC compare windows, each has a different hash
//#pragma unroll
//        for(char i = 0; i < VEC; i++)
//            //loop over all VEC bytes
//#pragma unroll
//            for(char j = 0; j < LEN; j++)
//            {
//                compare_window[j][0][i] = dictionary_0[hash[i]][j];
//                compare_window[j][1][i] = dictionary_1[hash[i]][j];
//                compare_window[j][2][i] = dictionary_2[hash[i]][j];
//                compare_window[j][3][i] = dictionary_3[hash[i]][j];
//#if VEC > 4
//                compare_window[j][4][i] = dictionary_4[hash[i]][j];
//                compare_window[j][5][i] = dictionary_5[hash[i]][j];
//                compare_window[j][6][i] = dictionary_6[hash[i]][j];
//                compare_window[j][7][i] = dictionary_7[hash[i]][j];
//#endif
//#if VEC > 8
//                compare_window[j][8][i]  = dictionary_8[hash[i]][j];
//                compare_window[j][9][i]  = dictionary_9[hash[i]][j];
//                compare_window[j][10][i] = dictionary_10[hash[i]][j];
//                compare_window[j][11][i] = dictionary_11[hash[i]][j];
//#endif
//#if VEC > 12
//                compare_window[j][12][i] = dictionary_12[hash[i]][j];
//                compare_window[j][13][i] = dictionary_13[hash[i]][j];
//                compare_window[j][14][i] = dictionary_14[hash[i]][j];
//                compare_window[j][15][i] = dictionary_15[hash[i]][j];
//#endif
//            }
//
//        //loop over compare windows
//#pragma unroll
//        for(char i = 0; i < VEC; i++)
//        {
//            //loop over frames in this compare window (they come from different dictionaries)
//            compare_offset[0][i] = dict_offset_0[hash[i]];
//            compare_offset[1][i] = dict_offset_1[hash[i]];
//            compare_offset[2][i] = dict_offset_2[hash[i]];
//            compare_offset[3][i] = dict_offset_3[hash[i]];
//#if VEC > 4
//            compare_offset[4][i] = dict_offset_4[hash[i]];
//            compare_offset[5][i] = dict_offset_5[hash[i]];
//            compare_offset[6][i] = dict_offset_6[hash[i]];
//            compare_offset[7][i] = dict_offset_7[hash[i]];
//#endif
//#if VEC > 8
//            compare_offset[8][i]  = dict_offset_8[hash[i]];
//            compare_offset[9][i]  = dict_offset_9[hash[i]];
//            compare_offset[10][i] = dict_offset_10[hash[i]];
//            compare_offset[11][i] = dict_offset_11[hash[i]];
//#endif
//#if VEC > 12
//            compare_offset[12][i] = dict_offset_12[hash[i]];
//            compare_offset[13][i] = dict_offset_13[hash[i]];
//            compare_offset[14][i] = dict_offset_14[hash[i]];
//            compare_offset[15][i] = dict_offset_15[hash[i]];
//#endif
//        }
//
//        //-----------------------------
//        // Dictionary update
//        //-----------------------------
//
//        //loop over different dictionaries to store different frames
//        //store one frame per dictionary
//        //loop over VEC bytes to store
//#pragma unroll
//        for(char i = 0; i < LEN; i++)
//        {
//            //store actual bytes
//            dictionary_0[hash[0]][i] = current_window[i+0];
//            dictionary_1[hash[1]][i] = current_window[i+1];
//            dictionary_2[hash[2]][i] = current_window[i+2];
//            dictionary_3[hash[3]][i] = current_window[i+3];
//#if VEC > 4
//            dictionary_4[hash[4]][i] = current_window[i+4];
//            dictionary_5[hash[5]][i] = current_window[i+5];
//            dictionary_6[hash[6]][i] = current_window[i+6];
//            dictionary_7[hash[7]][i] = current_window[i+7];
//#endif
//#if VEC > 8
//            dictionary_8[hash[8]][i]  = current_window[i+8];
//            dictionary_9[hash[9]][i]  = current_window[i+9];
//            dictionary_10[hash[10]][i] = current_window[i+10];
//            dictionary_11[hash[11]][i] = current_window[i+11];
//#endif
//#if VEC > 12
//            dictionary_12[hash[12]][i] = current_window[i+12];
//            dictionary_13[hash[13]][i] = current_window[i+13];
//            dictionary_14[hash[14]][i] = current_window[i+14];
//            dictionary_15[hash[15]][i] = current_window[i+15];
//#endif
//        }
//
//        //loop over VEC different dictionaries and write one word to each
//        dict_offset_0[hash[0]] = reset ? 0 : inpos - VEC + 0;
//        dict_offset_1[hash[1]] = reset ? 0 : inpos - VEC + 1;
//        dict_offset_2[hash[2]] = reset ? 0 : inpos - VEC + 2;
//        dict_offset_3[hash[3]] = reset ? 0 : inpos - VEC + 3;
//#if VEC > 4
//        dict_offset_4[hash[4]] = reset ? 0 : inpos - VEC + 4;
//        dict_offset_5[hash[5]] = reset ? 0 : inpos - VEC + 5;
//        dict_offset_6[hash[6]] = reset ? 0 : inpos - VEC + 6;
//        dict_offset_7[hash[7]] = reset ? 0 : inpos - VEC + 7;
//#endif
//#if VEC > 8
//        dict_offset_8[hash[8]]   = reset ? 0 : inpos - VEC + 8;
//        dict_offset_9[hash[9]]   = reset ? 0 : inpos - VEC + 9;
//        dict_offset_10[hash[10]] = reset ? 0 : inpos - VEC + 10;
//        dict_offset_11[hash[11]] = reset ? 0 : inpos - VEC + 11;
//#endif
//#if VEC > 12
//        dict_offset_12[hash[12]] = reset ? 0 : inpos - VEC + 12;
//        dict_offset_13[hash[13]] = reset ? 0 : inpos - VEC + 13;
//        dict_offset_14[hash[14]] = reset ? 0 : inpos - VEC + 14;
//        dict_offset_15[hash[15]] = reset ? 0 : inpos - VEC + 15;
//#endif
//
//        //-----------------------------
//        // Match search
//        //-----------------------------
//
//        //arrays to store length, best length etc..
//        ushort length_bool[VEC][VEC];
//
//        //loop over each comparison window frame
//        //one comes from each dictionary
//#pragma unroll
//        for(char i = 0; i < VEC; i++ )
//        {
//            //initialize length and done
//#pragma unroll
//            for(char l = 0; l < VEC; l++)
//            {
//                length_bool[i][l] = 0;
//            }
//
//            //loop over each current window
//#pragma unroll
//            for(char j = 0; j < VEC ; j++)
//            {
//                //loop over each char in the current window
//                //and corresponding char in comparison window
//#pragma unroll
//                for(char k = 0; k < LEN ; k++)
//                {	
//                    length_bool[i][j] |= (current_window[i + k] == compare_window[k][j][i]) << k;
//                }
//            }
//        }
//
//        unsigned short filtered_length_bool[VEC][VEC];
//
//        //after this the result is all 1's from the begining for however long my match is
//        // e.g. 00000111 means a match length of 3
//#pragma unroll
//        for(char i = 0; i < VEC; i++)
//        {
//#pragma unroll
//            for(char j = 0; j < VEC; j++)
//            {
//                unsigned short curr_match = length_bool[i][j];
//                curr_match = curr_match & ((curr_match << 1) | 0x01);
//                curr_match = curr_match & ((curr_match << 2) | 0x03);
//                curr_match = curr_match & ((curr_match << 4) | 0x0f);
//                curr_match = curr_match & ((curr_match << 8) | 0xff);
//                filtered_length_bool[i][j] = curr_match;
//            }
//        }
//
//        //this holds the max match found per current window
//        unsigned short max_match[VEC];
//
//        //OR all the matches for each current window to get the best one
//#pragma unroll
//        for(char i = 0; i < VEC; i++)
//        {
//            max_match[i] = 0;
//#pragma unroll
//            for(char j = 0; j < VEC; j++)
//            {
//                max_match[i] |=  filtered_length_bool[i][j];
//            }
//        }
//
//        unsigned short u_bestlength[VEC];
//        unsigned int   bestoffset[VEC];
//
//        //initialize u_bestlength
//#pragma unroll
//        for(char i = 0; i < VEC; i++)
//        {
//            u_bestlength[i] = 0;
//            bestoffset[i] = 0;
//        }
//
//        //for each current window
//#pragma unroll
//        for( char i = 0; i < VEC; i++ )
//        {
//            //is this the best length? if it is, the result of XOR should be 0
//#pragma unroll
//            for( char j = 0; j < VEC; j++ )
//            {
//                bestoffset[i]    = ((max_match[i] ^ filtered_length_bool[i][j]) == 0) && (compare_offset[j][i] != 0) && ((inpos-VEC+i)-(compare_offset[j][i]) < 0x40000) ? (inpos-VEC+i)-(compare_offset[j][i]) : bestoffset[i];
//                u_bestlength[i] |= ((max_match[i] ^ filtered_length_bool[i][j]) == 0) && (compare_offset[j][i] != 0) && ((inpos-VEC+i)-(compare_offset[j][i]) < 0x40000) ? max_match[i] : 0;
//            }
//        }
//
//        unsigned short u_bestlength_onehot[VEC];
//
//        //one-hot-encode u_bestlength
//#pragma unroll
//        for( char i = 0; i < VEC; i++ )
//        {
//            unsigned int onehot = (u_bestlength[i] + 1) >> 1;
//            u_bestlength_onehot[i] = onehot;
//        }
//
//        char bestlength[VEC];
//
//        //convert from one-hot to binary
//#pragma unroll
//        for(char i = 0; i < VEC; i++)
//            bestlength[i] = ((u_bestlength_onehot[i] & 0x8000) ? 0x10 : 0x00) | 
//                ((u_bestlength_onehot[i] & 0x7f80) ? 0x08 : 0x00) | 
//                ((u_bestlength_onehot[i] & 0x7878) ? 0x04 : 0x00) | 
//                ((u_bestlength_onehot[i] & 0x6666) ? 0x02 : 0x00) | 
//                ((u_bestlength_onehot[i] & 0x5555) ? 0x01 : 0x00);
//
//
//        //-----------------------------
//        // Filter matches step 1
//        //-----------------------------
//
//        //remove matches with offsets that are <= 0: this means they're self-matching or didn't match
//        //and	
//        //keep only the matches that, when encoded, take fewer bytes than the actual match length				
//#pragma unroll
//        for(char i = 0; i < VEC; i++)
//            bestlength[i] = ( (bestlength[i] >= 5) ||
//                    ((bestlength[i] == 4) && (bestoffset[i] < 0x800))) ? bestlength[i] : 0;
//
//        //remove matches covered by previous cycle
//#pragma unroll
//        for(char i = 0; i < VEC; i++)
//            bestlength[i] = i < first_valid_pos ? -1 : bestlength[i];
//
//        //-----------------------------
//        // Assign first_valid_pos
//        //-----------------------------
//
//        //this is the most important variable in the world --> it is the only loop-carried one
//        first_valid_pos = 0;
//
//#pragma unroll
//        for(char i = 0; i < VEC; i++)
//            first_valid_pos = bestlength[i] <= 0 ? first_valid_pos : i + bestlength[i];
//
//        int first_valid_full = first_valid_pos;
//
//        if(first_valid_pos >= VEC)
//            first_valid_pos -= VEC;
//        else
//            first_valid_pos = 0;
//
//        //-----------------------------
//        // Filter matches "last-fit"
//        //-----------------------------
//
//        //pre-fit stage removes the later matches that have EXACTLY the same reach
//#pragma unroll
//        for(char i = 0; i < VEC-1; i++)
//#pragma unroll
//            for(char j = 1; j < VEC; j++)
//                bestlength[j] = ((bestlength[i] + i) == (bestlength[j] + j)) && i < j && bestlength[j] > 0 && bestlength[i] > 0 ? 0 : bestlength[j];
//        //                 reach of bl[i]         reach of bl[j]	   
//
//        //look for location of golden matcher
//        int golden_matcher = 0;
//#pragma unroll
//        for(char i = 0; i < VEC; i++)
//            golden_matcher = (bestlength[i]+i == (first_valid_full)) ? i : golden_matcher;
//
//        //if something covers golden matcher --> remove it!
//#pragma unroll
//        for(char i = 0; i < VEC; i++)
//            bestlength[i] = ((bestlength[i] + i) > golden_matcher) && i < golden_matcher && bestlength[i] != -1 ? 0 : bestlength[i];
//
//        //another step to remove literals that will be covered by prior matches
//        //set those to '-1' because we will do nothing for them, not even emit symbol
//#pragma unroll
//        for(char i = 0; i < VEC-1; i++)
//#pragma unroll VEC
//            for(char j = 1; j < VEC-i; j++)
//                bestlength[i+j] = bestlength[i] > j ? -1 : bestlength[i+j];
//
//        //-----------------------------
//        // Encode LZ bytes
//        //-----------------------------
//
//        unsigned char output_buffer[VECX2];
//        int output_buffer_size = 0;
//
//        bool dontencode[VECX2];
//
//#pragma unroll
//        for (int i = 0; i < VECX2; i++) {
//            output_buffer[i] = 0;
//            dontencode[i] = true;
//        }
//
//        //output marker byte at start
//        if (reset) {
//            if (mod_hash & DEPTH) {
//                reset = false;
//                output_buffer[output_buffer_size] = marker;
//                dontencode[output_buffer_size++] = false;
//            }
//        } else {
//
//            //loop over all chars in this cycle and compose output 
//#pragma unroll
//            for(char i = 0; i < VEC; i++)
//            {
//                if(bestlength[i] == 0)
//                {
//                    dontencode[output_buffer_size] = false;
//                    output_buffer[output_buffer_size++] = current_window[i];
//
//                    if(current_window[i] == marker)
//                    {
//                        dontencode[output_buffer_size] = true;
//                        output_buffer[output_buffer_size++] = 0;
//                    }
//                }
//                else if(bestlength[i] > 0)
//                {
//                    //1-output marker
//                    dontencode[output_buffer_size] = false;
//                    output_buffer[output_buffer_size++] = marker;
//
//                    //2-output bestlength
//
//                    //fit b.l. in 4 bits and put in upper m.s.b's
//                    unsigned char bestlength_byte = (bestlength[i] - 3) << 4;
//
//                    //concat with lower 4 bestoffset bytes
//                    unsigned int offset = bestoffset[i];
//                    bestlength_byte |= (offset & 0xf);
//
//                    //write to output_buffer
//                    dontencode[output_buffer_size] = true;
//                    output_buffer[output_buffer_size++] = bestlength_byte;
//
//                    //3-output bestoffset
//
//                    //check how many more bytes we need for bestoffset (either one or two)
//                    int extra_offset_bytes = 0;
//
//                    if(offset < 0x800) //offset needs only one extra byte
//                    {
//                        dontencode[output_buffer_size] = true;
//                        output_buffer[output_buffer_size++] = (offset >> 4) & 0x7f;
//                    }
//                    else //offset needs two extra bytes
//                    {
//                        dontencode[output_buffer_size] = true;
//                        output_buffer[output_buffer_size++] =  (offset >> 4)  | 0x80;
//                        dontencode[output_buffer_size] = true;
//                        output_buffer[output_buffer_size++] = ((offset >> 11) & 0x7f);
//                    }
//                }
//            }
//        }
//        outpos_lz += output_buffer_size;
//
//        //-----------------------------
//        // Huffman encoding
//        //-----------------------------
//
//        //valid array contains '1' if there is data at this output_buffer position, zero otherwise		
//        bool valid[VECX2];
//
//#pragma unroll
//        for(char i = 0; i < VECX2; i++)
//        {
//            if(i < output_buffer_size)
//                valid[i] = true;
//            else
//                valid[i] = false;
//        }
//
//        unsigned short outdata[VECX2];
//        bool write = hufenc(huftable, huflen, output_buffer, valid, dontencode, outdata, leftover, &leftover_size);
//
//#pragma unroll
//        for (char i = 0; i < VECX2; i++) 
//        {
//            output_huffman[VECX2 * outpos_huffman + i] = (outdata[i]);
//        }
//        outpos_huffman = write ? outpos_huffman + 1 : outpos_huffman;
//
//        //-----------------------------
//        // Housekeeping
//        //-----------------------------
//
//        //increment input position
//        inpos += VEC;
//        if (reset) inpos = 0;
//
//    } while(inpos < insize);
//
//    //change to count of shorts
//    outpos_huffman = outpos_huffman * VECX2;
//    //write remaining bits
//    for (char i = 0; i < VECX2; i++) 
//    {
//        output_huffman[outpos_huffman + i] = (leftover[i]);
//    }
//
//    outpos_huffman *= 2;
//
//    outpos_huffman = outpos_huffman + (leftover_size >> 3) + ((leftover_size & 0x7) != 0);
//
//    //have to output first_valid_pos to tell 
//    //the host from where to start writing
//    *fvp = first_valid_pos;
//
//    //return compressed size as size of chars
//    *compsize_huffman = outpos_huffman;
//
//    //return lz compressed size
//    *compsize_lz = outpos_lz;	
//}





















//__kernel
//void kernel_huffman(              
//				__global uchar* restrict input_ht_data_global,
//				__global uchar* restrict input_hc_cd_global,
//				__global uchar* restrict input_hc_sta_global,
//				__global uchar* restrict rle_eight_data_global,
//				__global uchar* restrict output_huffman_data_global
//				)	
//{
//	/* uchar output_huffman_data_prv[N_PER_ITEM*4];
//
//	 uchar rle_eight_data_prv[N_PER_ITEM*4];
//
//	 #pragma unroll 2
//	 for (unsigned int i = index_start; i < index_end; i++) 
//	 {
//	 	rle_eight_data_prv[i-index_start] = rle_eight_data_global[i];
//	
//	 }*/
//
//	//根据编码表对8位切分的数据进行压缩
//	uint huffman_index = 0;
//	#pragma unroll 8
//	for (uint index = 0; index < BATCH; index++) {
//		//#pragma unroll 32
//		for (int k = input_hc_sta_global[rle_eight_data_global[index]]; k <= N; k++)
//		{
//	 		output_huffman_data_global[huffman_index / 8] = output_huffman_data_global[huffman_index / 8] << 1 | input_hc_cd_global[rle_eight_data_global[index]*N + k];//用huffman树来编码原序列
//	 		huffman_index++;
//		}
//	}
//
//	/*#pragma unroll 128
//	for(uint i=0;i<BATCH*8*2*2;i++){
//		output_huffman_data_global[i] = output_huffman_data_prv[i];
//	}*/
//}


//void eight_bit_cut( 
//					int copy
//				)
//{
//
//	float rle_data_tmp;
//	uchar2 rle_eight; 
//	uint cnt = 0;
//	for(uint i = 0;i < BATCH*16;i++){
//		if(cnt != 0){
//			rle_data_tmp = read_channel_intel(DATA_RLE[copy]);
//			rle_eight.s0 = (ushort)(rle_data_tmp) & 0xFF;
//			rle_eight.s1 = (ushort)(rle_data_tmp) >> 8;
//			if(copy == 0){
//
//				write_channel_intel(DATA_EBC[0], rle_eight.s0);
//				write_channel_intel(DATA_EBC[1], rle_eight.s1);
//			}
//			else if(copy == 1){
//				write_channel_intel(DATA_EBC[2], rle_eight.s0);
//				write_channel_intel(DATA_EBC[3], rle_eight.s1);
//			}
//		}
//		cnt++;
//	}
//}


//void fre_count( 
//				__global uint* restrict output_count,
//				int copy_f
//				)
//{
//
//	uchar rle_eight;
//	uint count[256];
//	uint cnt = 0;
//
//	#pragma unroll 32 
//	for(uint k = 0;k < 256;k++){
//		count[k] = 0;
//	}
//
//	for(uint i = 0;i < BATCH*16;i++){
//		if(cnt != 0){
//			rle_eight = read_channel_intel(DATA_EBC[copy_f]);
//			//count[rle_eight]++;
//		}
//		cnt++;
//	}
//	#pragma unroll 32 
//	for(uint j = 0;j < 256;j++){
//		output_count[j] = count[j];
//	}
//}


//#define EIGHT_BITS(copy) \
//\
//__kernel void eight_bit_cut ## copy () { \
//   eight_bit_cut(copy); \
//}
//
//	EIGHT_BITS(0)
//#if COPIES_E > 1
//   EIGHT_BITS(1)
//#endif
//#if COPIES_E > 2
//   EIGHT_BITS(2)
//#endif
//#if COPIES_E > 3
//   EIGHT_BITS(3)
//#endif
//#if COPIES_E > 4
//   EIGHT_BITS(4)
//#endif
//#if COPIES_E > 5
//   EIGHT_BITS(5)
//#endif
//#if COPIES_E > 6
//   EIGHT_BITS(6)
//#endif
//#if COPIES_E > 7
//   EIGHT_BITS(7)
//#endif
//#if COPIES_E > 8
//   EIGHT_BITS(8)
//#endif
//#if COPIES_E > 9
//   EIGHT_BITS(9)
//#endif
//#if COPIES_E > 10
//   EIGHT_BITS(10)
//#endif
//#if COPIES_E > 11
//   EIGHT_BITS(11)
//#endif



//#define FRE_CNT(copy_f) \
//\
//__kernel void fre_count ## copy_f (__global uint* restrict output_count) { \
//   fre_count(output_count, copy_f); \
//}
//
//
//	FRE_CNT(0)
//#if COPIES_F > 1
//   FRE_CNT(1)
//#endif
//#if COPIES_F > 2
//   FRE_CNT(2)
//#endif
//#if COPIES_F > 3
//   FRE_CNT(3)
//#endif
//#if COPIES_F > 4
//   FRE_CNT(4)
//#endif
//#if COPIES_F > 5
//   FRE_CNT(5)
//#endif
//#if COPIES_F > 6
//   FRE_CNT(6)
//#endif
//#if COPIES_F > 7
//   FRE_CNT(7)
//#endif
//#if COPIES_F > 8
//   FRE_CNT(8)
//#endif
//#if COPIES_F > 9
//   FRE_CNT(9)
//#endif
//#if COPIES_F > 10
//   FRE_CNT(10)
//#endif
//#if COPIES_F > 11
//   FRE_CNT(11)
//#endif



//channel float channel_load_data_to_quanlitization;
//channel Fre_Count channel_rle_coding_to_fre_count;
//channel uint  channel_rle_count;
//
//__kernel 
//__attribute((num_simd_work_items(SIMD_WORK_ITEMS)))
//void load_data_to_quanlitization(      // Input and output matrices
//                __global ushort* restrict input_image_data,
//				float camera_gain,     //相机增益
//				float conversion_error,//转换误差
//				uint quanstep          //量化步长
//				)
//{
//    // 本地变量
//	__local float image_local[group_height][group_width];
//	__local float error_local[group_height][group_width];
//	
//
//	// 私有变量
//	float quanlitization_tmp = 0;
//	int block_x_local = get_local_id(0);	
//    int block_y_local = get_local_id(1);
//	int block_x_group = get_group_id(0);	
//    int block_y_group = get_group_id(1);
//
//	// 分块载入数据
//	//#pragma unroll
//	//for (int i=0;i<group_height;i++){
//	//	#pragma unroll
//	//	for(int j=0;j<group_width;j++){
//	//		image_local[i][j] = input_image_data[(block_y_local*image_width/n_width+block_x_local*image_width*image_height/n_height) + image_width*i + j];
//	//	}	
//	//}
//	#pragma unroll 8
//	for (int i=0;i<group_height;i++){
//		#pragma unroll 8
//		for(int j=0;j<group_width;j++){
//			image_local[i][j] = input_image_data[group_width*i + j];
//		}	
//	}
//
//	// 光子转化
//	#pragma unroll 8
//	for (int i=0;i<group_height;i++){
//		#pragma unroll 8
//		for(int j=0;j<group_width;j++){	
//			image_local[i][j] = 2 * sqrt(image_local[i][j]*camera_gain+conversion_error*conversion_error);
//		}	
//	}
//
//	// 预测
//	#pragma unroll 8
//	for (int i = 0; i < group_height; i++){
//		error_local[i][0] = image_local[i][0];
//		error_local[i][1] = image_local[i][1] - image_local[i][1 - 1] ;
//		#pragma unroll 8
//		for (int j = 0; j < group_width; j++){				
//			if(j != 0 && j != 1)
//			{
//				error_local[i][j] = image_local[i][j] - (image_local[i][j-2] + (float)((int)(error_local[i][j - 1] / quanstep)));
//				image_local[i][j - 1] = image_local[i][j-2] + (float)((int)(error_local[i][j - 1] / quanstep));
//			}
//		}
//	}
//
//	// 量化
//	quanlitization_tmp = error_local[0][0];
//	#pragma unroll 8
//	for (int i = 0; i < group_height; i++){
//		#pragma unroll 8
//		for (int j = 0; j < group_width; j++){
//			error_local[i][j] = (float)((int)(error_local[i][j] / quanstep)*quanstep);
//		}
//	}
//	error_local[0][0] = quanlitization_tmp;
//
//	// 写入Channel
//	#pragma unroll 8
//	for (int i=0;i < group_height; i++){
//		#pragma unroll 8
//		for(int j=0;j < group_width; j++){
//			write_channel_intel(channel_load_data_to_quanlitization,error_local[i][j]);
//		}	
//	}
//	
//}
//
//
//__kernel 
//__attribute((num_simd_work_items(SIMD_WORK_ITEMS)))
//void rle_coding_to_fre_count()
//{
//	// 本地变量
//	__local float error_local[group_height][group_width];
//	__local float rle_local[group_height*group_width*2];
//	__local uchar rle_eight_local[group_height*group_width*4];	
//	__local uint frequency_count[N];
//	__local Fre_Count fre_count_str;
//	
//	// 私有变量
//	float rle_current_data = 0;
//	uint rle_count_tmp = 0;
//	uint rle_count = 0;
//	uchar frequency_temp = 0;
//	int block_x_local = get_local_id(0);	
//    int block_y_local = get_local_id(1);
//	int block_x_group = get_group_id(0);	
//    int block_y_group = get_group_id(1);
//
//	// 从Channel读取数据
//	#pragma unroll 8
//	for (uint i = 0; i < group_height; i++){
//		#pragma unroll 8
//		for(uint j = 0; j < group_width; j++){
//			error_local[i][j] = read_channel_intel(channel_load_data_to_quanlitization);
//		}	
//	}
//
//	// 游程编码
//	rle_current_data = error_local[0][0];
//	#pragma unroll 8
//	for (uint i = 0; i < group_height; i++)
//	{
//		#pragma unroll 8
//		for(uint j = 0;j < group_width; j++ ){
//			if (error_local[i][j] == rle_current_data)
//			{
//				rle_count_tmp++;
//			}
//			else
//			{
//				rle_local[rle_count] = rle_count_tmp;
//				rle_local[++rle_count] = rle_current_data;
//				rle_count_tmp = 1;
//				rle_current_data = error_local[i][j];
//				rle_count++;
//			}
//		}
//	}
//	rle_local[rle_count] = rle_count_tmp;
//	rle_local[++rle_count] = rle_current_data;
//	rle_count = rle_count + 1;
//
//	// 8位切分
//	#pragma unroll 128
//	for (uint i = 0; i < group_height*group_width*2; i++) {
//		rle_eight_local[(2 * i)+1] = (ushort)(rle_local[i]) & 0xFF;
//		rle_eight_local[(2 * i)] = (ushort)(rle_local[i]) >> 8;	
//	}
//	// 将后面剩余的部分置0
//	#pragma unroll 128
//	for(uint i = group_height*group_width*2;i < group_height*group_width*4; i++){
//		rle_eight_local[i] = 0;
//	}
//	rle_count = rle_count * 2;
//
//
//	// 数字频率统计
//	// for(uint i = 0; i < n; i++){
//	// 	frequency_count[i] = 123;
//	// }
//	#pragma unroll 256
//	for (uint i = 0;i < rle_count; i++)
//	{
//		frequency_temp  = rle_eight_local[i]; 
//		frequency_count[frequency_temp]++; 
//	}
//
//	// 将统计的频数赋值给结构体
//	#pragma unroll 256
//	for (uint i = 0;i < N; i++)
//	{
//		fre_count_str.data[i] = frequency_count[i];
//	}
//
//	//// 写入Channel
//	//write_channel_intel(channel_rle_coding_to_fre_count,fre_count_str);
//	//write_channel_intel(channel_rle_count,rle_count);
//}
//
//
////__kernel 
////__attribute((num_simd_work_items(SIMD_WORK_ITEMS)))
////void huffman_creation( 
////					 __global uint* restrict output_image_data
////					 )
////{
////	//// 本地变量
////	//__local uint frequency_count[N];
////	//__local Fre_Count fre_count_str[n_height*n_width*BLOCK_SIZE*BLOCK_SIZE];
////	//
////	//// 私有变量
////	//uint rle_count = 0;
////
////	////从Channel读取数据
////	//for (uint i = 0;i < BLOCK_SIZE*BLOCK_SIZE*n_height*n_width;i++)
////	//{
////	//	fre_count_str[i] = read_channel_intel(channel_rle_coding_to_fre_count); 
////	//}
////	//rle_count = read_channel_intel(channel_rle_count);
////
////	
////	//// 将聚合的数据分解得到总频率
////	//for(uint i=0;i<N; i++){	
////	//	frequency_count[i] = 0;
////	//	for (uint j = 0;j < BLOCK_SIZE*BLOCK_SIZE*n_height*n_width; j++){
////
////	//		//printf("%3d = %3d %d\n",i,frequency_count[i],fre_count_str[j].data[i]);
////	//		frequency_count[i] = frequency_count[i] + fre_count_str[j].data[i];
////	//		
////	//	}
////	//	//printf("%3d = %d \n",i,frequency_count[i]);
////	//	output_image_data[i] = frequency_count[i];
////	//}
////	
////}




