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

// The maximum number of nodes in the Huffman tree is 2^(8+1)-1 = 511 
#define MAX_TREE_NODES 511

//Maximum length of huffman codes
#define MAX_HUFFCODE_BITS 16

typedef struct {
    unsigned char *BytePtr;
    unsigned int  BitPos;
} huff_bitstream_t;

typedef struct {
    int Symbol;
    unsigned int Count;
    unsigned int Code;
    unsigned int Bits;
} huff_sym_t;

typedef struct huff_encodenode_struct huff_encodenode_t;

struct huff_encodenode_struct {
    huff_encodenode_t *ChildA, *ChildB;
    int Count;
    int Symbol;
    int Level;
};

typedef struct huff_decodenode_struct huff_decodenode_t;

struct huff_decodenode_struct {
    huff_decodenode_t *ChildA, *ChildB;
    int Symbol;
};

//---------------------------------------------------------------------------------------
//  FUNCTION PROTOTYPES
//---------------------------------------------------------------------------------------

void LZ_Uncompress(unsigned char *in, unsigned char *out, unsigned int insize );
void Huffman_Uncompress( unsigned char *in, unsigned char *out, huff_encodenode_t *root, unsigned int insize, unsigned int outsize, unsigned char marker );

void _Huffman_InitBitstream( huff_bitstream_t *stream, unsigned char *buf );
unsigned int _Huffman_ReadBit( huff_bitstream_t *stream );
unsigned int _Huffman_Read8Bits( huff_bitstream_t *stream );
void _Huffman_WriteBits( huff_bitstream_t *stream, unsigned int x, unsigned int bits );
unsigned char _Huffman_Hist( unsigned char *in, huff_sym_t *sym, unsigned int size );
void _Huffman_StoreTree( huff_encodenode_t *node, huff_sym_t *sym, unsigned int code, unsigned int bits );
int _Tree_Depth(huff_encodenode_t *root);
void _Tree_Annotate_Depth(huff_encodenode_t *root);
int _Tree_Limit_Depth(huff_encodenode_t *root, int max_depth);
void _Tree_Debug_Print(huff_encodenode_t *root);
huff_encodenode_t * _Huffman_MakeTree( huff_sym_t *sym, huff_encodenode_t *nodes, unsigned int num_symbols);
huff_decodenode_t * _Huffman_RecoverTree( huff_decodenode_t *nodes, huff_bitstream_t *stream, unsigned int *nodenum );
unsigned short reverse(unsigned short a, int n);

long GetFileSize( FILE *f );
