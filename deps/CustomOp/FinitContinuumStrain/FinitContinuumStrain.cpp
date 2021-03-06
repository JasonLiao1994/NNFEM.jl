#include "tensorflow/core/framework/op_kernel.h"
#include "tensorflow/core/framework/tensor_shape.h"
#include "tensorflow/core/platform/default/logging.h"
#include "tensorflow/core/framework/shape_inference.h"
#include<cmath>


#ifdef USE_GPU
#include "tensorflow/core/util/gpu_kernel_helper.h"
namespace tensorflow{
  typedef Eigen::GpuDevice GPUDevice;
  void forwardGPU(const GPUDevice &d);
  void backwardGPU(const GPUDevice &d);
}
#endif
using namespace tensorflow;
#include "FinitContinuumStrain.h"


REGISTER_OP("FinitContinuumStrain")

.Input("state : double")
.Output("strain : double")
.SetShapeFn([](::tensorflow::shape_inference::InferenceContext* c) {
    
        shape_inference::ShapeHandle state_shape;
        TF_RETURN_IF_ERROR(c->WithRank(c->input(0), 1, &state_shape));

        c->set_output(0, c->Matrix(-1,3));
    return Status::OK();
  });

REGISTER_OP("FinitContinuumStrainGrad")

.Input("grad_strain : double")
.Input("strain : double")
.Input("state : double")
.Output("grad_state : double");


class FinitContinuumStrainOp : public OpKernel {
private:
  
public:
  explicit FinitContinuumStrainOp(OpKernelConstruction* context) : OpKernel(context) {

  }

  void Compute(OpKernelContext* context) override {    
    DCHECK_EQ(1, context->num_inputs());
    
    
    const Tensor& state = context->input(0);
    
    
    const TensorShape& state_shape = state.shape();
    
    
    DCHECK_EQ(state_shape.dims(), 1);

    // extra check
        
    // create output shape
    
    TensorShape strain_shape({domain.ngauss,3});
            
    // create output tensor
    
    Tensor* strain = NULL;
    OP_REQUIRES_OK(context, context->allocate_output(0, strain_shape, &strain));
    
    // get the corresponding Eigen tensors for data access
    
    auto state_tensor = state.flat<double>().data();
    auto strain_tensor = strain->flat<double>().data();   

    // implement your forward function here 

    // TODO:
    forward_FinitContinuumStrain(strain_tensor, state_tensor);

  }
};
REGISTER_KERNEL_BUILDER(Name("FinitContinuumStrain").Device(DEVICE_CPU), FinitContinuumStrainOp);



class FinitContinuumStrainGradOp : public OpKernel {
private:
  
public:
  explicit FinitContinuumStrainGradOp(OpKernelConstruction* context) : OpKernel(context) {
    
  }
  
  void Compute(OpKernelContext* context) override {
    
    
    const Tensor& grad_strain = context->input(0);
    const Tensor& strain = context->input(1);
    const Tensor& state = context->input(2);
    
    
    const TensorShape& grad_strain_shape = grad_strain.shape();
    const TensorShape& strain_shape = strain.shape();
    const TensorShape& state_shape = state.shape();
    
    
    DCHECK_EQ(grad_strain_shape.dims(), 2);
    DCHECK_EQ(strain_shape.dims(), 2);
    DCHECK_EQ(state_shape.dims(), 1);

    // extra check
    // int m = Example.dim_size(0);
        
    // create output shape
    
    TensorShape grad_state_shape(state_shape);
            
    // create output tensor
    
    Tensor* grad_state = NULL;
    OP_REQUIRES_OK(context, context->allocate_output(0, grad_state_shape, &grad_state));
    
    // get the corresponding Eigen tensors for data access
    
    auto state_tensor = state.flat<double>().data();
    auto grad_strain_tensor = grad_strain.flat<double>().data();
    auto strain_tensor = strain.flat<double>().data();
    auto grad_state_tensor = grad_state->flat<double>().data();   

    // implement your backward function here 

    // TODO:
    forward_FinitContinuumStrain(grad_state_tensor, grad_strain_tensor, strain_tensor, state_tensor);
    
  }
};
REGISTER_KERNEL_BUILDER(Name("FinitContinuumStrainGrad").Device(DEVICE_CPU), FinitContinuumStrainGradOp);


/***************************************************************************************
**********************            GPU Operator            ******************************
***************************************************************************************/


#ifdef USE_GPU
class FinitContinuumStrainOpGPU : public OpKernel {
private:
  
public:
  explicit FinitContinuumStrainOpGPU(OpKernelConstruction* context) : OpKernel(context) {

  }

  void Compute(OpKernelContext* context) override {    
    DCHECK_EQ(1, context->num_inputs());
    
    
    const Tensor& state = context->input(0);
    
    
    const TensorShape& state_shape = state.shape();
    
    
    DCHECK_EQ(state_shape.dims(), 1);

    // extra check
        
    // create output shape
    
    TensorShape strain_shape({-1,3});
            
    // create output tensor
    
    Tensor* strain = NULL;
    OP_REQUIRES_OK(context, context->allocate_output(0, strain_shape, &strain));
    
    // get the corresponding Eigen tensors for data access
    
    auto state_tensor = state.flat<double>().data();
    auto strain_tensor = strain->flat<double>().data();   

    // implement your forward function here 

    // TODO:

  }
};
REGISTER_KERNEL_BUILDER(Name("FinitContinuumStrain").Device(DEVICE_GPU), FinitContinuumStrainOpGPU);

class FinitContinuumStrainGradOpGPU : public OpKernel {
private:
  
public:
  explicit FinitContinuumStrainGradOpGPU(OpKernelConstruction* context) : OpKernel(context) {
    
  }
  
  void Compute(OpKernelContext* context) override {
    
    
    const Tensor& grad_strain = context->input(0);
    const Tensor& strain = context->input(1);
    const Tensor& state = context->input(2);
    
    
    const TensorShape& grad_strain_shape = grad_strain.shape();
    const TensorShape& strain_shape = strain.shape();
    const TensorShape& state_shape = state.shape();
    
    
    DCHECK_EQ(grad_strain_shape.dims(), 2);
    DCHECK_EQ(strain_shape.dims(), 2);
    DCHECK_EQ(state_shape.dims(), 1);

    // extra check
    // int m = Example.dim_size(0);
        
    // create output shape
    
    TensorShape grad_state_shape(state_shape);
            
    // create output tensor
    
    Tensor* grad_state = NULL;
    OP_REQUIRES_OK(context, context->allocate_output(0, grad_state_shape, &grad_state));
    
    // get the corresponding Eigen tensors for data access
    
    auto state_tensor = state.flat<double>().data();
    auto grad_strain_tensor = grad_strain.flat<double>().data();
    auto strain_tensor = strain.flat<double>().data();
    auto grad_state_tensor = grad_state->flat<double>().data();   

    // implement your backward function here 

    // TODO:
    
  }
};
REGISTER_KERNEL_BUILDER(Name("FinitContinuumStrainGrad").Device(DEVICE_GPU), FinitContinuumStrainGradOpGPU);

#endif