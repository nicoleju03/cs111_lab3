ifeq ($(shell uname -s),Darwin)
	CFLAGS = -std=gnu17 -pthread -Wall -O0 -pipe -fno-plt -fPIC -I. -I/opt/homebrew/include
	LDFLAGS = -pthread -L$(shell brew --prefix)/lib -largp
else
	CFLAGS = -std=gnu17 -pthread -Wall -O0 -pipe -fno-plt -fPIC -I.
	LDFLAGS = -lrt -pthread -Wl,-O1,--sort-common,--as-needed,-z,relro,-z,now
endif

#TSAN = -fsanitize=thread -fsanitize=undefined -g3 -Og
#ASAN = -fsanitize=address -fsanitize=undefined -g3 -Og
#SANITIZE=$(TSAN)
#CFLAGS += $(SANITIZE)
#LDFLAGS += $(SANITIZE)

OBJS = \
  hash-table-common.o \
  hash-table-base.o \
  hash-table-v1.o \
  hash-table-v2.o \
  hash-table-tester.o

FILENAME=README.md
UID = $(shell cat ${FILENAME} | grep '## UID'| grep -oe '\([0-9.]*\)')
SUBMISSION_FILES = hash-table-v1.c hash-table-v2.c README.md
.PHONY: all
all: hash-table-tester

hash-table-tester: $(OBJS)
	$(CC) $(LDFLAGS) $^ -o $@
tar:
	@tar -cf ${UID}-lab3-submission.tar ${SUBMISSION_FILES}

.PHONY: clean
clean:
	rm -f $(OBJS) hash-table-tester
