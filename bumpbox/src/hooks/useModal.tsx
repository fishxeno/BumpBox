import { type ComponentType, type JSX, useCallback, useState } from "react";

export interface BaseModalProps {
    show: boolean;
    onClose: () => void;
}

type RequiredLiteralKeys<T> = keyof { [K in keyof T as string extends K ? never : number extends K ? never :
    // eslint-disable-next-line @typescript-eslint/no-empty-object-type
    {} extends Pick<T, K> ? never : K]: 0 }

export default function useModal<P>(
    Modal: ComponentType<BaseModalProps & Omit<P, keyof BaseModalProps>>,
    ...[props]: RequiredLiteralKeys<P> extends never ? [(P & Partial<BaseModalProps>)?] : [(P & Partial<BaseModalProps>)]
) : [ JSX.Element, () => void, () => void, boolean ]

{
    const [ isShowing, setIsShowing ] = useState(false);

    const onShow = useCallback(() => {
        setIsShowing(true);
    }, [])

    const onHide = useCallback(() => {
        setIsShowing(false);
    }, [])

    return [
        (
            <Modal
                {...props as P}
                show={isShowing && props?.show !== false}
                onClose={(...args) => {
                    setIsShowing(false);
                    //call onclose if specified in params
                    props?.onClose?.(...args);
                }}
            />
        ),
        onShow,
        onHide,
        isShowing
    ]
}