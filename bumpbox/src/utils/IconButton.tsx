import type { SvgIconComponent } from "@mui/icons-material"
import classNames from "classnames"
import React from "react"
import type { CSSProperties } from "react"
import { Button, type ButtonProps } from "react-bootstrap"
import styles from "./utils.module.css"

export interface BaseButtonProps extends ButtonProps {
    transparent?: boolean,
    iconHtmlColor?: string,
    iconStyles?: CSSProperties,
    border?: boolean;
}
export interface ButtonWithIconProps extends BaseButtonProps {
    Icon: SvgIconComponent | React.FC<React.SVGProps<SVGSVGElement>>;
    label?: string;
}
export interface ButtonWithLabelProps extends BaseButtonProps {
    Icon?: SvgIconComponent | React.FC<React.SVGProps<SVGSVGElement>>;
    label: string;
}
export type IconButtonProps = ButtonWithIconProps | ButtonWithLabelProps

const IconButton = React.forwardRef<HTMLButtonElement, IconButtonProps>(({ className, Icon, style, transparent, iconHtmlColor, iconStyles, label, border, ...props }, ref) => {
    return (
        <Button
            variant='clear'
            className={classNames('d-flex', 'justify-content-center', 'align-items-center', styles.icon, className, transparent && styles.transparentIcon, (border ?? transparent) && styles.border)}
            style={{
                color: iconHtmlColor,
                borderRadius: label !== undefined ? undefined : '6px',
                width: label !== undefined ? undefined : '1.6rem',
                height: label !== undefined ? undefined : '1.6rem',
                ...style,
            }}
            ref={ref}
            {...props}
        >
            {
                Icon !== undefined && (
                    <Icon
                        style={{
                            fontSize: '1.25rem',
                            color: iconHtmlColor,
                            ...iconStyles
                        }}
                        className={label ? 'me-2' : undefined}
                    />
                )
            }
            {
                label !== undefined && <span>{label}</span>
            }
        </Button>
    )
});
export default IconButton;