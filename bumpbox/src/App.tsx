import { Button, Modal, Form, Container, Col, Card } from "react-bootstrap";
import "./App.css";
import React from "react";
import { Formik } from "formik";
import * as Yup from "yup";
import { Close, Done } from "@mui/icons-material";
import BootstrapModalFooter from "./utils/BootstrapModalFooter";
import { useItem, useItemMutations } from "./api/itemService";
import { BootstrapInput } from "./utils/components/FormikBootstrapinputs";

function App() {
    const [showModal, setShowModal] = React.useState(false);
    const initialValues = {
        phone: "",
        item_name: "",
        price: 0,
        description: "",
        days: 0,
    };

    const { data: item } = useItem();

    const { mutate: createItem, error } = useItemMutations("CREATE_ITEM");
    const schema = Yup.object({
        phone: Yup.string().required("Phone number is required").matches(/^\d{8}$/, "Phone number must be 8 digits"),
        item_name: Yup.string().required("Item name is required"),
        price: Yup.number().required("Price is required").positive(),
        description: Yup.string().required('Description is required'),
        days: Yup.number().required('Number of days is required').integer().positive(),
    });

    const onSubmit = (values: typeof initialValues) => {
        setShowModal(false);
        const { phone, item_name, price, description, days } = values;
        createItem({
            phone,
            item_name,
            price,
            description,
            days,
        });
    };


    return (
        <Container className="d-flex justify-content-center align-items-center vh-100">
            <div>
                <Card>
                    <Card.Body>
                        <Card.Title>Welcome to BumpBox</Card.Title>
                        <Card.Text>
                            {item ? `Current item: ${item.data.item_name}` : "No items available"}
                        </Card.Text>
                    </Card.Body>
                </Card>
            </div>
            <div className="card">
                <h1 className="title">BumpBox</h1>
                <Button onClick={() => setShowModal(true)}>Open Modal</Button>
                <Formik
                    initialValues={initialValues}
                    onSubmit={onSubmit}
                    validationSchema={schema}
                >
                    {({ submitForm, values }) => (
                        <Form noValidate>
                            <Modal show={showModal}>
                                <Modal.Header
                                    closeButton
                                    onHide={() => setShowModal(false)}
                                >
                                    <Modal.Title>Modal heading</Modal.Title>
                                </Modal.Header>
                                <Modal.Body>
                                    <Form.Group as={Col} lg>
                                        <BootstrapInput
                                            id="item_name"
                                            type="text"
                                            required
                                            value={values.item_name}
                                            placeholder="Item Name"
                                            label="Item Name"
                                        />
                                    </Form.Group>
                                    <Form.Group as={Col} lg>
                                        <BootstrapInput
                                            id="phone"
                                            type="text"
                                            required
                                            value={values.phone}
                                            placeholder="Phone Number"
                                            label="Phone Number"
                                        />
                                    </Form.Group>
                                    <Form.Group as={Col} lg>
                                        <BootstrapInput
                                            id="price"
                                            type="number"
                                            required
                                            value={values.price}
                                            placeholder="Price"
                                            label="Price"
                                        />
                                    </Form.Group>
                                    <Form.Group as={Col} lg>
                                        <BootstrapInput
                                            id="description"
                                            type="text"
                                            required
                                            value={values.description}
                                            placeholder="Description"
                                            label="Description"
                                        />
                                    </Form.Group>
                                    <Form.Group as={Col} lg>
                                        <BootstrapInput
                                            id="days"
                                            type="number"
                                            required
                                            value={values.days}
                                            placeholder="Number of Days"
                                            label="Number of Days"
                                        />
                                    </Form.Group>

                                </Modal.Body>
                                <BootstrapModalFooter
                                    error={error}
                                    cancelBtnProps={{
                                        onClick: () => setShowModal(false),
                                        Icon: Close,
                                        label: "Cancel",
                                    }}
                                    confirmBtnProps={{
                                        Icon: Done,
                                        label: "Submit",
                                        onClick: () => {
                                            console.log("clicked submit");
                                            submitForm();
                                        },
                                    }}
                                />
                            </Modal>
                        </Form>
                    )}
                </Formik>
            </div>
            {/*  */}
        </Container>
    );
}

export default App;
