import { useLocation } from "react-router-dom";
import { useMemo } from "react";

// the query string for you.
// A custom hook that builds on useLocation to parse
export default function useQuery() {
    const { search } = useLocation();
    return useMemo(() => new URLSearchParams(search), [search]);
}