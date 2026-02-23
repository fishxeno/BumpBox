@echo off
REM Quick test script for Windows - simulates complete ESP32 flow

echo ========================================
echo   BumpBox Quick Test
echo ========================================
echo.

echo [1/4] Triggering capture...
curl -X POST http://localhost:8080/api/locker/trigger-capture -H "Content-Type: application/json" -d "{\"lockerId\":\"locker1\"}" 2>nul
timeout /t 1 >nul

echo [2/4] Checking trigger status...
curl http://localhost:8080/api/locker/capture-trigger 2>nul
echo.
timeout /t 1 >nul

echo [3/4] Simulating detection (Headphones)...
curl -X POST http://localhost:8080/api/test/simulate-detection -H "Content-Type: application/json" -d "{\"lockerId\":\"locker1\",\"itemType\":\"Headphones\"}" 2>nul
echo.
timeout /t 1 >nul


echo ========================================
echo   Test Complete!
echo ========================================
echo.
echo Now open Flutter app and press "Sell Item"
echo The detection should appear within 2 seconds
echo.
pause
