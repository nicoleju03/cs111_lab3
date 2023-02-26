## UID: 605691503
(IMPORTANT: Only replace the above numbers with your true UID, do not modify spacing and newlines, otherwise your tarfile might not be created correctly)

# Hash Hash Hash

In this lab, we implement two different strategies of using multi-threads to manipulate hash tables. The first strategy emphasizes correctness, with just one lock. The second strategy incorporates both correctness and performance, with multiple locks. We use the pthread library to create and utilize  mutexes.

## Building

Build the hash-table-tester executable  by running ```make```.

## Running

Run the program with ```./hash-table-tester -t [number of threads] -s [number of hash table entries]```.

For example, if you run ```./hash-table-tester -t 4 -s 80000``` on a 4 core machine, the results are as follows:

Generation: 69,357 usec

Hash table base: 1,329,660 usec
- 0 missing


## First Implementation

In my first implementation, I declared and initialized the mutex statically at the top of the file; all of the threads will share this mutex. If I had omitted the static keywoard, there would be issues with mutual exclusion because each thread would get its own copy of the lock. I called pthread_mutex_lock at the start of the hash_table_v1_add_entry function and called pthread_mutex_ulock at the end of that function. The reason this implementation is correct is because since this function edits the hash table, a shared resource between multiple threads of this process, there is likely a critical section within this function. Without locks, multiple threads could attempt to insert into the hash table at the same time, which could cause issues (eg one of the insertions could get "lost"). Thus, if we lock the entire function, we will not get any issues with one thread adding to the hash table at the same time as another thread. A thread must acquire the lock in order to add to the hash table, and it will release the lock when it is finished so other threads can use it (so we do not have infinite waiting).  We have not changed anything else except adding in the lock, so the program will still work correctly.

Note that the lock is deleted when the hash table function is destroyed, preventing memory leaks.

### Performance

Running ```./hash-table-tester -t 4 -s 80000``` results in the following:

Generation: 69,357

Hash table base: 1,329,660 usec
- 0 missing

Hash table v1: 4,633,151 usec
- 0 missing

Version 1 is 3.48 times slower than the base version because it provides mutual exclusion of the hash_table_v1_add_entry function, meaning each thread must wait for other threads to complete this entire function before they can access the code. Multiple threads cannot add to the hash table at the same time. Thus, there is not much parallelism as there could be, despite it being a multithreaded environment. There is also overhead for creating, acquiring, and releasing the lock that would have not been present if no locks were used in the first table. The base hash table runs in serial and does not need locks. Once a thread runs, it can run without stopping. There is also no additional overhead added from threads waiting on locks and acquiring/releasing them. For these reasons, the base hash table performs better than version 1.

We can decrease the number of threads (while maintaining the same amount of work) and run ```./hash-table-tester -t 2 16000```. The results are as follows:

Generation: 65,628 usec

Hash table base: 1,171,251 usec
- 0 missing

Hash table v1: 2,559,957 usec
-0 missing

With 2 threads, v1 is 2.19 times slower than the base version. The reason the slow down is less extreme than the previous case with 4 threads is because with less threads,each thread spends less time waiting on other threads to release the lock. In other words, there is less contention for the lock. There is also less overhead from acquiring and releasing the lock (you have to do it fewer times). Thus, the threads can perform insertions into the hash table faster.

## Second Implementation

In my second implementation, I used a mutex for each hash table entry (each bucket of the hash table). I declared an array of size HASH_TABLE_CAPACITY to hold all of the locks. In the hash_table_v1_create() function, inside the for loop that creates each hash table entry, I initialized all of the locks. Threads need to acquire a lock to access the critical sections within the hash_table_v2_add_entry function. The lock they acquire (&mutexes[index], where index specifies the index in the hash table), corresponds to the bucket of the hash table they are trying to edit. I believe there are two critical sections in the add_entry function. The first critical section is the two lines of code that set the list_head variable and the list_entry variable; these need to be executed together because the return value of the get_list_entry function is affected by the list_head. If one thread is interrupted right after the first line, and another thread adds an entry to the same bucket (changing the list_head), then the second line will not yield the same results. The other critical section is SLIST_INSERT_HEAD(list_head, list_entry, pointers). Here, you are inserting a list entry at the head of the list of the particular hash table entry. If this section of code is not locked, then one thread can get interrupted right before changing the head pointer, and another thread can complete an insertion, resulting in the loss of a list entry when the first thread changes the head pointer. I protected both of these critical sections with pthread_mutex_lock(&mutexes[index]) and pthread_mutex_unlock(&mutexes[index]). The rest of this function is not a critical section, and multiple threads can access it concurrently, so it does not need to be locked.

This implementation should work because there are only contention issues when multiple threads try to insert a list_entry into the same bucket, so you only need mutual exclusion within each bucket, not for the entire hash table. Having locks for each bucket prevents threads from inserting into the same bucket at the same time. It is okay for different threads to insert into different hash table entires concurrently, so not having a lock for the entire hash table should not be a problem.

Note that all of the locks are deleted when the hash table is deleted.

### Performance

Running ```./hash-table-tester -t 4 -s 80000``` yields the following results:

Generation: 65,863 usec

Hash table base: 1,579,996 usec
- 0 missing

Hash table v1: 4,309,783 usec
- 0 missing

Hash table v2: 377,787 usec
- 0 missing

The speedup of version 2 compared to the base hash table is 4.18x faster (note that this is around t times faster, where t is the number of threads). The reason that this performance is far better than version 1 is because in version 2, the locks are at a finer granularity. Previously, a thread acquired a lock for the entire hash table; this means that regardless of which hash_table_entry a thread is inserting into, it has exclusive access to the entire hash table. No other thread can add into other buckets at the same time, even though this will not cause contention issues. This results in unnecessary waiting and overhead. In version 2, when a thread wants to insert into the hash table, it acquires the lock that is specific to the bucket and gets exclusive access to the bucket, not the entire hash table. So if other threads want to perform insertions into the other buckets, it can do so concurrenly, resulting in more parallelism. Furthermore, version 1 locks the entire add_entry function, including code that is not part of a critical section. Version 2 locks just the critical sections, so each thread holds the lock for less time and can release it sooner for the other locks to acquire. For these reasons, version 2's performance is better than that of version 1. And because version 2 allows a multithreaded system to take better advantage of parallelism, it is also faster than the base hash table, which is run serially. The speed achieved through this parallelism outweighs the overhead of acquiring and releasing locks.

Running it with 2 threads and 160000 entries, we get:

Generation: 60,234 usec

Hash table base: 1,417,481 usec
- 0 missing

Hash table v1: 2,016,389 usec
- 0 missing

Hash table v2: 737,915 usec
- 0 missing

Here, the speedup of v2 is 1.98 times faster than the base implementation (note that this is also about t times faster, where t is the number of threads). You should get more parallelism with more threads, since more threads are able to run concurrently, shortening the overall time to complete the tasks. The performance benefits of the added parallelism increase with the number of threads, up until the number of cores (in this case, we have 4 cores). Thus, the speedup is greater if there are 4 threads running as compared to just 2. 

## Cleaning up

Clean up all binary files by running ```make clean```.
