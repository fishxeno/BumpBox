import { BrowserRouter, Navigate, Route, Routes } from "react-router-dom";
import KioskDashboard from "./pages/KioskDashboard";
import SellScreen from "./pages/SellScreen";
import "./App.css";

function App() {
    return (
        <BrowserRouter>
            <Routes>
                <Route path="/" element={<KioskDashboard />} />
                <Route path="/sell" element={<SellScreen />} />
                <Route path="*" element={<Navigate to="/" replace />} />
            </Routes>
        </BrowserRouter>
    );
}

export default App;
