/* предопределенный макрос: загрузчик                         */
#define BOOT_LOADER_CODE_AREA_ADDRESS                 0x7c00
#define BOOT_LOADER_CODE_AREA_ADDRESS_OFFSET          0x0000

/* предопределенный макрос: сегмент стека                       */
#define BOOT_LOADER_STACK_SEGMENT                     0x7c00

#define BOOT_LOADER_ROOT_OFFSET                       0x0200
#define BOOT_LOADER_FAT_OFFSET                        0x0200

#define BOOT_LOADER_STAGE2_ADDRESS                    0x1000
#define BOOT_LOADER_STAGE2_OFFSET                     0x0000 

/* предопределенный макрос: разметка дискеты                  */
#define BOOT_DISK_SECTORS_PER_TRACK                   0x0012
#define BOOT_DISK_HEADS_PER_CYLINDER                  0x0002
#define BOOT_DISK_BYTES_PER_SECTOR                    0x0200
#define BOOT_DISK_SECTORS_PER_CLUSTER                 0x0001

/* предопределенный макрос: разметка файловой системы                  */
#define FAT12_FAT_POSITION                            0x0001
#define FAT12_FAT_SIZE                                0x0009
#define FAT12_ROOT_POSITION                           0x0013
#define FAT12_ROOT_SIZE                               0x000e
#define FAT12_ROOT_ENTRIES                            0x00e0
#define FAT12_END_OF_FILE                             0x0ff8

/* предопределенный макрос: загрузчик                         */
#define BOOT_SIGNATURE                                0xaa55

/* пользовательские макросы */
/* макрос для установки среды */
.macro initEnvironment
     call _initEnvironment
.endm
/* макрос для отображения строки на экране.   */
/* Для выполнения этой операции он вызывает функцию _writeString */
/* параметр: вводная строка                */
.macro writeString message
     pushw \message
     call  _writeString
.endm
/* макрос для считывания сектора в памяти  */
/* Вызывает функцию _readSector со следующими параметрами   */
/* параметры: номер сектора               */
/*            адрес загрузки                */
/*            смещение адреса          */
/*            количество считываемых секторов      */
.macro readSector sectorno, address, offset, totalsectors
     pushw \sectorno
     pushw \address
     pushw \offset
     pushw \totalsectors
     call  _readSector
     addw  $0x0008, %sp
.endm
/* макрос для поиска файла на FAT-диске.   */
/* Для этого он вызывает макрос readSector */
/* параметры: адрес корневого каталога     */
/*               целевой адрес             */
/*               целевое смещение          */
/*               размер корневого каталога */
.macro findFile file
     /* считывание таблицы FAT в память */
     readSector $FAT12_ROOT_POSITION, $BOOT_LOADER_CODE_AREA_ADDRESS, $BOOT_LOADER_ROOT_OFFSET, $FAT12_ROOT_SIZE
     pushw \file
     call  _findFile
     addw  $0x0002, %sp
.endm
/* макрос для преобразования заданного кластера в номер сектора */
/* Для этого он вызывает _clusterToLinearBlockAddress */
/* параметр: номер кластера */
.macro clusterToLinearBlockAddress cluster
     pushw \cluster
     call  _clusterToLinearBlockAddress
     addw  $0x0002, %sp
.endm
/* макрос для загрузки целевого файла в память.  */
/* Он вызывает findFile и загружает данные соответствующего файла в память */
/* по адресу 0x1000:0x0000 */
/* параметр: имя целевого файла */
.macro loadFile file
     /* проверка наличия файла */
     findFile \file

     pushw %ax
     /* считывание таблицы FAT в память */
     readSector $FAT12_FAT_POSITION, $BOOT_LOADER_CODE_AREA_ADDRESS, $BOOT_LOADER_FAT_OFFSET, $FAT12_FAT_SIZE

     popw  %ax
     movw  $BOOT_LOADER_STAGE2_OFFSET, %bx
_loadCluster:
     pushw %bx
     pushw %ax
 
     clusterToLinearBlockAddress %ax
     readSector %ax, $BOOT_LOADER_STAGE2_ADDRESS, %bx, $BOOT_DISK_SECTORS_PER_CLUSTER

     popw  %ax
     xorw %dx, %dx
     movw $0x0003, %bx
     mulw %bx
     movw $0x0002, %bx
     divw %bx

     movw $BOOT_LOADER_FAT_OFFSET, %bx
     addw %ax, %bx
     movw $BOOT_LOADER_CODE_AREA_ADDRESS, %ax
     movw %ax, %es
     movw %es:(%bx), %ax
     orw  %dx, %dx
     jz   _even_cluster
_odd_cluster:
     shrw $0x0004, %ax
     jmp  _done 
_even_cluster:
     and $0x0fff, %ax
_done:
     popw %bx
     addw $BOOT_DISK_BYTES_PER_SECTOR, %bx
     cmpw $FAT12_END_OF_FILE, %ax
     jl  _loadCluster

     /* выполнение ядра */
     initKernel     
.endm
/* параметры: имя целевого файла */
/* макрос для передачи права выполнения файлу, загруженному */
/* в память по адресу 0x1000:0x0000                     */
/* параметры: none                       */
.macro initKernel
     /* инициализация ядра */
     movw  $(BOOT_LOADER_STAGE2_ADDRESS), %ax
     movw  $(BOOT_LOADER_STAGE2_OFFSET) , %bx
     movw  %ax, %es
     movw  %ax, %ds
     jmp   $(BOOT_LOADER_STAGE2_ADDRESS), $(BOOT_LOADER_STAGE2_OFFSET)
.endm 
