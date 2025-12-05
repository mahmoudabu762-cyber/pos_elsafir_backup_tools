@echo off
setlocal EnableDelayedExpansion

REM ===== 1) اسم المشروع =====
set "PROJECT_NAME=pos_elsafir"

REM ===== 2) مسار السكربت (مكان ملفات JSON + مكان JSON النتيجة) =====
set "SOURCE=%~dp0"
set "RESULT_FILE=%SOURCE%backup_result.json"

REM نحذف ملف النتيجة القديم إن وجد
if exist "%RESULT_FILE%" del "%RESULT_FILE%"

REM ===== 3) مسار النسخ الأساسي على C =====
set "MAIN_TARGET=C:\%PROJECT_NAME%"

REM ===== 4) تجهيز فولدرات C =====
if not exist "%MAIN_TARGET%" mkdir "%MAIN_TARGET%"
if not exist "%MAIN_TARGET%\separated_backups" mkdir "%MAIN_TARGET%\separated_backups"
if not exist "%MAIN_TARGET%\combined_backups" mkdir "%MAIN_TARGET%\combined_backups"

REM ===== 5) نقل النسخ المنفصلة إلى C =====
for %%f in ("%SOURCE%backup_*_*.json") do (
    move "%%f" "%MAIN_TARGET%\separated_backups" >nul
)

REM ===== 6) نقل النسخة المجمعة إلى C =====
for %%f in ("%SOURCE%backup_*.json") do (
    echo %%~nxf | findstr /r "_.*\.json" >nul
    if errorlevel 1 (
        move "%%f" "%MAIN_TARGET%\combined_backups" >nul
    )
)

REM هل في أي حاجة في C؟
set "copied_any=0"
if exist "%MAIN_TARGET%\separated_backups\*.json" set "copied_any=1"
if exist "%MAIN_TARGET%\combined_backups\*.json" set "copied_any=1"

if "%copied_any%"=="0" (
    >"%RESULT_FILE%" echo {
    >>"%RESULT_FILE%" echo   "status": "error",
    >>"%RESULT_FILE%" echo   "copied_to": [],
    >>"%RESULT_FILE%" echo   "message": "^❌ فشلت عملية النسخ الاحتياطي — لم يتم حفظ أي ملفات."
    >>"%RESULT_FILE%" echo }
    goto selfdestruct
)

REM ===== 7) البحث عن الأقراص الداخلية والخارجية (غير C) =====
set "INTERNAL_DRIVES="
set "EXTERNAL_DRIVES="

for /f "skip=1 tokens=1,2 delims= " %%A in ('wmic logicaldisk get DeviceID^,DriveType') do (
    if not "%%A"=="" (
        set "LETTER=%%A"
        set "TYPE=%%B"

        REM إزالة النقطتين
        set "LETTER=!LETTER::=!"

        if /I not "!LETTER!"=="C" (
            if "!TYPE!"=="3" (
                REM ثابت = داخلي
                if defined INTERNAL_DRIVES (
                    set "INTERNAL_DRIVES=!INTERNAL_DRIVES!,!LETTER!"
                ) else (
                    set "INTERNAL_DRIVES=!LETTER!"
                )
            ) else if "!TYPE!"=="2" (
                REM Removable = خارجي
                if defined EXTERNAL_DRIVES (
                    set "EXTERNAL_DRIVES=!EXTERNAL_DRIVES!,!LETTER!"
                ) else (
                    set "EXTERNAL_DRIVES=!LETTER!"
                )
            )
        )
    )
)

REM ===== 8) نسخ المحتوى من C إلى الأقراص الداخلية =====
if defined INTERNAL_DRIVES (
    for %%D in (!INTERNAL_DRIVES!) do (
        set "INT_TARGET=%%D:\%PROJECT_NAME%"
        if not exist "!INT_TARGET!" mkdir "!INT_TARGET!"
        if not exist "!INT_TARGET!\separated_backups" mkdir "!INT_TARGET!\separated_backups"
        if not exist "!INT_TARGET!\combined_backups" mkdir "!INT_TARGET!\combined_backups"

        xcopy "%MAIN_TARGET%\separated_backups" "!INT_TARGET!\separated_backups" /E /Y >nul
        xcopy "%MAIN_TARGET%\combined_backups" "!INT_TARGET!\combined_backups" /E /Y >nul
    )
)

REM ===== 9) نسخ المحتوى من C إلى الأقراص الخارجية =====
if defined EXTERNAL_DRIVES (
    for %%D in (!EXTERNAL_DRIVES!) do (
        set "EXT_TARGET=%%D:\%PROJECT_NAME%"
        if not exist "!EXT_TARGET!" mkdir "!EXT_TARGET!"
        if not exist "!EXT_TARGET!\separated_backups" mkdir "!EXT_TARGET!\separated_backups"
        if not exist "!EXT_TARGET!\combined_backups" mkdir "!EXT_TARGET!\combined_backups"

        xcopy "%MAIN_TARGET%\separated_backups" "!EXT_TARGET!\separated_backups" /E /Y >nul
        xcopy "%MAIN_TARGET%\combined_backups" "!EXT_TARGET!\combined_backups" /E /Y >nul
    )
)

REM ===== 10) بناء الرسالة النصية =====
set "msg=^✅ تم حفظ النسخة الاحتياطية على القرص C داخل المجلد:^nC:\\%PROJECT_NAME%^n(نسخة مجمعة + نسخة منفصلة)^n^n"

if defined INTERNAL_DRIVES (
    for %%D in (!INTERNAL_DRIVES!) do (
        set "msg=!msg!^✅ وتم حفظ نفس النسخة على القرص الداخلي %%D داخل المجلد:^n%%D:\\%PROJECT_NAME%^n^n"
    )
)

if defined EXTERNAL_DRIVES (
    for %%D in (!EXTERNAL_DRIVES!) do (
        set "msg=!msg!^✅ وتم حفظ نفس النسخة على القرص الخارجي %%D داخل المجلد:^n%%D:\\%PROJECT_NAME%^n^n"
    )
)

if not defined INTERNAL_DRIVES if not defined EXTERNAL_DRIVES (
    set "msg=!msg!^⚠️ لم يتم العثور على أي قرص داخلي أو خارجي إضافي."
)

REM ===== 11) تحديد status =====
set "status=success"
if not defined INTERNAL_DRIVES if not defined EXTERNAL_DRIVES set "status=warning"

REM ===== 12) كتابة JSON =====
>"%RESULT_FILE%" echo {
>>"%RESULT_FILE%" echo   "status": "!status!",
>>"%RESULT_FILE%" echo   "copied_to": [
>>"%RESULT_FILE%" echo     "C"
if defined INTERNAL_DRIVES (
    for %%D in (!INTERNAL_DRIVES!) do (
        >>"%RESULT_FILE%" echo    ,"%%D"
    )
)
if defined EXTERNAL_DRIVES (
    for %%D in (!EXTERNAL_DRIVES!) do (
        >>"%RESULT_FILE%" echo    ,"%%D"
    )
)
>>"%RESULT_FILE%" echo   ],
>>"%RESULT_FILE%" echo   "message": "!msg!"
>>"%RESULT_FILE%" echo }

:selfdestruct
del "%~f0"

endlocal
exit
