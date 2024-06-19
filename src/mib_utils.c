#include "mib_utils.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

const char* only_file_name(const char* absolute_file_path) {
    const char* rslash = strrchr(absolute_file_path, '/');
    return (rslash != NULL) ? rslash + 1 : absolute_file_path;
}

unsigned int num_of_headers(
    FILE* mib_ptr,
    const unsigned int stride
    )
{
  unsigned int num_hdr=0;
  long int original_fpi=0, file_size=0;

  /*store the original position*/
  original_fpi = ftell(mib_ptr);

  /*move to the end*/
  if (fseek(mib_ptr, 0L, SEEK_END) != 0) {
    const char* current_file = only_file_name(__FILE__);
    fprintf(stderr, "%s:%d: error: failed to seek to end of the MIB file\n", current_file, __LINE__);
    goto restore;
  }

  /*get the current position (i.e. end position)*/
  file_size = ftell(mib_ptr);

  /*printf("File size: %ld\n", file_size);*/

  if (stride == 0) {
    const char* current_file = only_file_name(__FILE__);
    fprintf(stderr, "%s:%d: error: frame stride cannot be zero\n", current_file, __LINE__);
    num_hdr = 0;
  }
  else {
    if ((file_size % stride) != 0) {
      const char* current_file = only_file_name(__FILE__);
      fprintf(stderr, "%s:%d: error: the stride of the frame is apparently "
              "incorrect (it cannot divide the MIB file into an integral "
              "number of frames)\n", current_file, __LINE__);
      goto restore;
    }
    num_hdr = file_size / stride;
  }

  /*go back to the original position*/
restore:
  if (fseek(mib_ptr, original_fpi, SEEK_SET) != 0) {
    const char* current_file = only_file_name(__FILE__);
    fprintf(stderr, "%s:%d: error: failed to seek to the original position of the MIB file\n", current_file, __LINE__);
    num_hdr = 0;
  }

  return num_hdr;
}

void header_meta_from_first(
    FILE* mib_ptr,
    char* header_id,
    unsigned int* header_bytes,
    unsigned int* num_chips,
    unsigned int* det_x,
    unsigned int* det_y
    )
{
  char header_buf[40];
  long int original_fpi=0;

  /*store the original position*/
  original_fpi = ftell(mib_ptr);

  /*move to the beginning*/
  if (fseek(mib_ptr, 0L, SEEK_SET) != 0) {
    const char* current_file = only_file_name(__FILE__);
    fprintf(stderr, "%s:%d: error: failed to seek to beginning of the MIB file\n", current_file, __LINE__);
    goto restore;
  }

  /*get enough section of the first header*/
  if (fgets(header_buf, sizeof(header_buf), mib_ptr) == NULL) {
    perror("error: failed to read data from header");
    goto restore;
  }

  /*assign value (skip sequence number)*/
  int n = sscanf(header_buf, "%3s,%*[^,],%u,%u,%u,%u", header_id, header_bytes, num_chips, det_x, det_y);

  /*fail to assign enough value */
  if (n != 5) {
    const char* current_file = only_file_name(__FILE__);
    fprintf(stderr, "%s:%d: error: failed to assign header meta value\n", current_file, __LINE__);
    goto restore;
  }
  if (n == EOF) {
    const char* current_file = only_file_name(__FILE__);
    fprintf(stderr, "%s:%d: error: the first header appears to be empty\n", current_file, __LINE__);
    goto restore;
  }

  /*go back to the original position*/
restore:
  if (fseek(mib_ptr, original_fpi, SEEK_SET) != 0) {
    const char* current_file = only_file_name(__FILE__);
    fprintf(stderr, "%s:%d: error: failed to seek to the original position of the MIB file\n", current_file, __LINE__);
  }
}
