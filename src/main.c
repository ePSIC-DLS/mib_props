#include <stdio.h>
#include <stdlib.h>

int main() {
  char* mib_path;
  FILE* mib_ptr;
  int status=EXIT_SUCCESS;
  unsigned int num_headers=0, frame_stride=0;
  char header_id[4];
  unsigned int header_bytes=0, num_chips=0, det_x=0, det_y=0;

  mib_path = "20240522_125025_data.mib";

   /*open the MIB file*/
  if ((mib_ptr = fopen(mib_path, "rb")) == NULL) {
    const char* current_file = only_file_name(__FILE__);
    fprintf(stderr, "%s:%d: error: failed to open the MIB file %s\n", current_file, __LINE__, mib_path);
    return EXIT_FAILURE;
  }

  /*get some metadata from the first header*/
  header_meta_from_first(mib_ptr, header_id, &header_bytes, &num_chips, &det_x, &det_y);

  /*check if the header version is MQ1*/
  if (strncmp(header_id, "MQ1", 3) != 0) {
    const char* current_file = only_file_name(__FILE__);
    fprintf(stderr, "%s:%d: error: only the version 'MQ1' is currently supported\n", current_file, __LINE__);
    status = EXIT_FAILURE;
    goto close_file;
  }

   /*get number of headers/frames*/
  frame_stride = header_bytes + det_x * det_y;
  if ((num_headers = num_of_headers(mib_ptr, frame_stride)) == 0) {
    const char* current_file = only_file_name(__FILE__);
    fprintf(stderr, "%s:%d: error: failed to determine the number of headers\n", current_file, __LINE__);
    status = EXIT_FAILURE;
    goto close_file;
  }


  mq1q* mq1q_headers = (mq1q*)malloc(sizeof(mq1q)*65536);

  /*mq1q mq1q_headers[20];*/

  /*printf("mq1q size: %lu\n", sizeof(mq1q));*/

  /*+1 to accommodate the null byte*/
  char header_buffer[768+1];
  for (int i=0; i<65536; ++i) {

    fgets(header_buffer, sizeof(header_buffer), mib_ptr);
    /*error handling*/


    parse_mq1_quad(header_buffer, &mq1q_headers[i]);



    print_quad_mib_header(mq1q_headers[i]);


    /*move the file by det_x*det_y*/
    /*guard last one*/
    fseek(mib_ptr, (long int)det_x*det_y, SEEK_CUR);
  }


close_file:
  if (fclose(mib_ptr) == EOF) {
    const char* current_file = only_file_name(__FILE__);
    fprintf(stderr, "%s:%d: error: failed to close the file %s\n", current_file, __LINE__, mib_path);
    status = EXIT_FAILURE;
  }

  free(mq1q_headers); mq1q_headers=NULL;

  return status;
}
