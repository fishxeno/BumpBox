import { Close, Delete, Done } from '@mui/icons-material';
import classNames from 'classnames';
import { Container, Modal } from 'react-bootstrap';
import IconButton, { type IconButtonProps } from './IconButton';
import type { JSX } from 'react/jsx-dev-runtime';

type TIconButtonProps = Omit<IconButtonProps, 'label'> & { label?: string }; // make label optional

interface BootstrapModalFooterProps {
    error: Error | null;
    deleteBtnProps?: TIconButtonProps;
    besideDeleteBtn?: JSX.Element;
    cancelBtnProps?: TIconButtonProps;
    confirmBtnProps: TIconButtonProps;
}

const BootstrapModalFooter = ({
    error,
    deleteBtnProps,
    besideDeleteBtn,
    cancelBtnProps,
    confirmBtnProps: { className: confirmClassName, ..._confirmBtnProps },
}: BootstrapModalFooterProps) => {
    return (
        <Modal.Footer>
            <Container>
                <div className="d-flex flex-wrap justify-content-end">
                    {error !== null && (
                        <p className="text-danger w-100 text-end">{error.message}</p>
                    )}

                    <div className="d-flex me-auto">
                        {deleteBtnProps !== undefined && (
                            <>
                                {(() => {
                                    const { className: deleteClassName, ..._deleteBtnProps } =
                                        deleteBtnProps;
                                    return (
                                        <IconButton
                                            transparent
                                            Icon={Delete}
                                            iconHtmlColor="var(--danger)"
                                            label="Delete"
                                            variant="danger"
                                            className={classNames(
                                                'align-self-start border-danger text-danger',
                                                deleteClassName && deleteClassName
                                            )}
                                            {..._deleteBtnProps}
                                        />
                                    );
                                })()}
                            </>
                        )}

                        {besideDeleteBtn}
                    </div>

                    {cancelBtnProps !== undefined && (
                        <>
                            {(() => {
                                const { className: cancelClassName, ..._cancelBtnProps } =
                                    cancelBtnProps;
                                return (
                                    <IconButton
                                        transparent
                                        Icon={Close}
                                        iconHtmlColor="var(--primary)"
                                        label="Cancel"
                                        variant="outline-primary"
                                        className={classNames(
                                            'me-2 border-primary text-primary',
                                            cancelClassName && cancelClassName
                                        )}
                                        {..._cancelBtnProps}
                                    />
                                );
                            })()}
                        </>
                    )}

                    <IconButton
                        Icon={Done}
                        label="Save"
                        className={classNames(
                            'border-primary text-primary border-primary',
                            confirmClassName && confirmClassName
                        )}
                        {..._confirmBtnProps}
                    />
                </div>
            </Container>
        </Modal.Footer>
    );
};

export default BootstrapModalFooter;
