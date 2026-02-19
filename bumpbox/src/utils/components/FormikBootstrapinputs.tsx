import classNames from "classnames";
import { useField } from "formik";
import type { JSX } from "react";
import { Form, InputGroup, type FormControlProps } from "react-bootstrap";

export interface BootstrapInputProps extends FormControlProps {
    label?: string;
    inputGroupText?: string | JSX.Element;
    inputGroupSize?: 'sm' | 'lg';
    inputGroupPosition?: 'prefix' | 'suffix';
    required?: boolean;
    displayError?: boolean;
    min?: string | number | undefined;
    max?: string | number | undefined;
    step?: string | number | undefined;
    rows?: string | undefined; //only applicable for text area
    validText?: string;
}

interface BootstrapFormLabelProps {
    className?: string;
    htmlFor: string | undefined;
    children: React.ReactNode;
}
export const BootstrapFormLabel = ({ children, className, ...props }: BootstrapFormLabelProps) => {
    return (
        <Form.Label
            className={classNames(
                'fw-bold text-uppercase text-secondary small',
                className !== undefined ? className : ''
            )}
            {...props}
        >
            {children}
        </Form.Label>
    );
};

export const BootstrapInput = ({
    label,
    inputGroupText,
    inputGroupSize,
    inputGroupPosition = 'suffix',
    required = true,
    displayError = true,
    validText = 'Looks good!',
    ...props
}: BootstrapInputProps) => {
    // useField() returns [formik.getFieldProps(), formik.getFieldMeta()]
    // which we can spread on <input>. We can use field meta to show an error
    // message if the field is invalid and it has been touched (i.e. visited)
    const [field, meta] = useField(props.id as string);

    const formControl = (
        <Form.Control isInvalid={meta.touched && !!meta.error} {...field} {...props} />
    );

    const inputGroupContainer = !!inputGroupText && (
        <InputGroup size={inputGroupSize}>
            {inputGroupPosition === 'prefix' && <InputGroup.Text>{inputGroupText}</InputGroup.Text>}
            {formControl}
            {inputGroupPosition === 'suffix' && <InputGroup.Text>{inputGroupText}</InputGroup.Text>}
        </InputGroup>
    );

    return (
        <>
            {label && (
                <BootstrapFormLabel htmlFor={props.id}>
                    {label} {required && <span className="text-danger">*</span>}
                </BootstrapFormLabel>
            )}

            {inputGroupContainer || formControl}

            {meta.touched && meta.error === undefined && props.isValid && (
                <Form.Control.Feedback type="valid">{validText}</Form.Control.Feedback>
            )}

            {meta.touched && meta.error !== undefined && displayError && (
                <Form.Control.Feedback type="invalid">{meta.error}</Form.Control.Feedback>
            )}
        </>
    );
};