#!/bin/bash -x

cd /src

# Edit the OpenH264 source to make it compatible with Emscripten single-threaded mode
cat <<EOF > codec/decoder/core/src/wels_decoder_thread.cpp.tmp
#ifdef __EMSCRIPTEN_SINGLE_THREADED__

#include <errno.h>
#include <time.h>
#include <semaphore.h>

extern "C" int sem_timedwait(sem_t *sem, const struct timespec *abs_timeout) {
    errno = ENOSYS;
    return -1;
}

extern "C" int GetCPUCount() {
    return 1;
}

int EventCreate(SWelsDecEvent* e, int manualReset, int initialState) { return 0; }
void EventPost(SWelsDecEvent* e) { /* no-op */ }
int EventWait(SWelsDecEvent* e, int32_t timeout) { return 0; }
void EventReset(SWelsDecEvent* e) { /* no-op */ }
void EventDestroy(SWelsDecEvent* e) { /* no-op */ }
int SemCreate(SWelsDecSemphore* s, long value, long max) { return 0; }
int SemWait(SWelsDecSemphore* s, int32_t timeout) { return 0; }
void SemRelease(SWelsDecSemphore* s, long* prev_count) { /* no-op */ }
void SemDestroy(SWelsDecSemphore* s) { /* no-op */ }
int ThreadCreate(SWelsDecThread* t, LPWELS_THREAD_ROUTINE fn, void* arg) { return 0; }
int ThreadWait(SWelsDecThread* t) { return 0; }

#endif
EOF

# Append the patch to the original file at the top
cat codec/decoder/core/src/wels_decoder_thread.cpp codec/decoder/core/src/wels_decoder_thread.cpp.tmp > codec/decoder/core/src/wels_decoder_thread.cpp

rm codec/decoder/core/src/wels_decoder_thread.cpp.tmp

# Set Emscripten compilation flags for WebAssembly (include GetCPUCount header)
export CFLAGS="-O3 -fno-stack-protector -U_FORTIFY_SOURCE -s USE_PTHREADS=0 -D__EMSCRIPTEN_SINGLE_THREADED__ -include ./codec/decoder/core/inc/wels_decoder_thread.h"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="$CFLAGS"

# Build and install a static OpenH264 library to $INSTALL_DIR (prefix)
emmake make OS=linux ARCH=asmjs install-static PREFIX="${INSTALL_DIR}"

# Fix ERROR: openh264 not found using pkg-config
emranlib $INSTALL_DIR/lib/libopenh264.a
